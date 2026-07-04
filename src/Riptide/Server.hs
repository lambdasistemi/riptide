module Riptide.Server
    ( ServerState
    , ServerConfig (..)
    , ServerConfigError (..)
    , currentSession
    , handleClientCommand
    , newServerState
    , readServerConfig
    , readServerConfigFrom
    , runServerFromEnvironment
    , serverApplication
    ) where

-- \|
-- Module      : Riptide.Server
-- Description : Socket-free server command dispatch.

import Control.Concurrent.MVar
    ( MVar
    , modifyMVar
    , modifyMVar_
    , newMVar
    , readMVar
    )
import Control.Exception
    ( SomeException
    , finally
    , try
    )
import Control.Monad (void)
import Data.Aeson
    ( eitherDecode
    , encode
    )
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Foldable (traverse_)
import Data.IORef (newIORef)
import Data.List
    ( find
    , partition
    )
import Data.Maybe (fromMaybe)
import Data.String (fromString)
import Data.Text (Text)
import Data.Text qualified as Text
import Network.Wai (Application)
import Network.Wai.Application.Static
    ( defaultFileServerSettings
    , staticApp
    )
import Network.Wai.Handler.Warp qualified as Warp
import Network.Wai.Handler.WebSockets (websocketsOr)
import Network.WebSockets qualified as WebSockets
import Riptide.Eval (validateControlPatternWithDefinitions)
import Riptide.Playback
    ( PlaybackBackend
    , PlaybackMode (..)
    , activateTrackPlayback
    , dryPlaybackBackend
    , readPlaybackMode
    , realTidalPlaybackBackend
    , silenceTrackPlayback
    )
import Riptide.Protocol
    ( ClientCommand (..)
    , CommandFailure (..)
    , ServerEvent (..)
    , ValidationResult (..)
    )
import Riptide.Session
    ( DefinitionBlock (..)
    , DefinitionId
    , Session (..)
    , activateTrackText
    , addDefinitionBlock
    , applyDefinitionBlock
    , editDefinitionBlock
    , saveTrackText
    , silenceTrack
    )
import Riptide.Store
    ( loadSession
    , saveDefinitions
    , saveSession
    , saveTracks
    )
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

data ServerConfig = ServerConfig
    { serverHost :: String
    , serverPort :: Int
    , serverFrontendDir :: FilePath
    , serverStateDirectory :: FilePath
    , serverSlotCapacity :: Int
    }
    deriving stock (Show, Eq)

data ServerConfigError
    = InvalidServerPort String
    | InvalidSlotCapacity String
    deriving stock (Show, Eq)

data ServerState = ServerState
    { serverSession :: MVar Session
    , serverPlayback :: PlaybackBackend
    , serverStateDir :: FilePath
    , serverClients :: MVar [(Int, WebSockets.Connection)]
    , serverNextClientId :: MVar Int
    }

newServerState
    :: FilePath -> PlaybackBackend -> Session -> IO ServerState
newServerState serverStateDir serverPlayback initialSession = do
    serverSession <- newMVar initialSession
    serverClients <- newMVar []
    serverNextClientId <- newMVar 0
    pure ServerState{..}

currentSession :: ServerState -> IO Session
currentSession =
    readMVar . serverSession

readServerConfig :: IO (Either ServerConfigError ServerConfig)
readServerConfig =
    readServerConfigFrom lookupEnv

readServerConfigFrom
    :: (String -> IO (Maybe String))
    -> IO (Either ServerConfigError ServerConfig)
readServerConfigFrom lookupVar = do
    configuredHost <- lookupVar "RIPTIDE_HOST"
    configuredPort <- lookupVar "RIPTIDE_PORT"
    configuredFrontendDir <- lookupVar "RIPTIDE_FRONTEND_DIR"
    configuredStateDir <- lookupVar "RIPTIDE_STATE_DIR"
    configuredSlotCapacity <- lookupVar "RIPTIDE_SLOT_CAPACITY"
    pure $ do
        serverPort <- parseServerPort configuredPort
        serverSlotCapacity <- parseSlotCapacity configuredSlotCapacity
        pure
            ServerConfig
                { serverHost = fromMaybe "127.0.0.1" configuredHost
                , serverFrontendDir =
                    fromMaybe "frontend/dist" configuredFrontendDir
                , serverStateDirectory =
                    fromMaybe ".riptide-state" configuredStateDir
                , ..
                }

runServerFromEnvironment :: IO ()
runServerFromEnvironment = do
    configResult <- readServerConfig
    case configResult of
        Left err ->
            fail $ "invalid riptide server configuration: " <> show err
        Right config -> do
            playbackModeResult <- readPlaybackMode
            playbackMode <- either (fail . show) pure playbackModeResult
            session <-
                loadSession
                    (serverSlotCapacity config)
                    (serverStateDirectory config)
            playback <- playbackBackendFor playbackMode
            server <-
                newServerState
                    (serverStateDirectory config)
                    playback
                    session
            Warp.runSettings
                (warpSettings config)
                (serverApplication server $ serverFrontendDir config)

serverApplication :: ServerState -> FilePath -> Application
serverApplication server frontendDir =
    websocketsOr
        WebSockets.defaultConnectionOptions
        (websocketApplication server)
        (staticApp $ defaultFileServerSettings frontendDir)

handleClientCommand
    :: ServerState -> ClientCommand -> IO [ServerEvent]
handleClientCommand server command =
    case command of
        ValidateText source ->
            validateText server source
        SetSession clientSession ->
            stateCommand server command $ \session -> do
                let updated =
                        session
                            { sessionTracks = sessionTracks clientSession
                            , sessionDefinitions =
                                sessionDefinitions clientSession
                            }
                saveSession (serverStateDir server) updated
                pure $ commandSucceeded updated
        ActivateTrackText trackIdent textIdent ->
            stateCommand server command $ \session -> do
                let candidate = activateTrackText trackIdent textIdent session
                result <-
                    activateTrackPlayback
                        (serverPlayback server)
                        candidate
                        trackIdent
                pure $
                    case result of
                        Right () -> commandSucceeded candidate
                        Left err -> commandFailed session command (showText err)
        SilenceTrack trackIdent ->
            stateCommand server command $ \session -> do
                result <-
                    silenceTrackPlayback
                        (serverPlayback server)
                        session
                        trackIdent
                pure $
                    case result of
                        Right () -> commandSucceeded $ silenceTrack trackIdent session
                        Left err -> commandFailed session command (showText err)
        SaveTrackText trackIdent textIdent source ->
            stateCommand server command $ \session -> do
                let updated = saveTrackText trackIdent textIdent source session
                saveTracks (serverStateDir server) (sessionTracks updated)
                pure $ commandSucceeded updated
        SaveDefinition definition name code ->
            stateCommand server command $ \session -> do
                let updated = saveDefinitionBlock definition name code session
                saveDefinitions
                    (serverStateDir server)
                    (sessionDefinitions updated)
                pure $ commandSucceeded updated
        ApplyDefinition definition ->
            stateCommand server command $ \session -> do
                let updated = applyDefinitionBlock definition session
                saveDefinitions
                    (serverStateDir server)
                    (sessionDefinitions updated)
                pure $ commandSucceeded updated

validateText :: ServerState -> Text -> IO [ServerEvent]
validateText server source = do
    session <- currentSession server
    result <-
        validateControlPatternWithDefinitions
            (appliedDefinitions session)
            (Text.unpack source)
    pure
        [ TextValidated $
            case result of
                Right _ -> ValidationSucceeded source
                Left err -> ValidationFailed source $ showText err
        ]

stateCommand
    :: ServerState
    -> ClientCommand
    -> (Session -> IO (Session, [ServerEvent]))
    -> IO [ServerEvent]
stateCommand server _command action =
    modifyMVar (serverSession server) $ \session -> do
        (updated, events) <- action session
        pure (updated, events)

commandSucceeded :: Session -> (Session, [ServerEvent])
commandSucceeded session =
    (session, [StateSnapshot session])

commandFailed
    :: Session -> ClientCommand -> Text -> (Session, [ServerEvent])
commandFailed session command message =
    ( session
    ,
        [ CommandFailed $
            CommandFailure
                { failureCommand = command
                , failureMessage = message
                }
        ]
    )

saveDefinitionBlock
    :: DefinitionId
    -> Text
    -> Text
    -> Session
    -> Session
saveDefinitionBlock definition name code session
    | hasDefinition definition session =
        editDefinitionBlock definition name code session
    | otherwise =
        addDefinitionBlock definition name code session

hasDefinition :: DefinitionId -> Session -> Bool
hasDefinition definition session =
    case find ((== definition) . blockId) (sessionDefinitions session) of
        Just _ -> True
        Nothing -> False

appliedDefinitions :: Session -> [String]
appliedDefinitions session =
    Text.unpack . blockApplied
        <$> filter (not . Text.null . blockApplied) (sessionDefinitions session)

showText :: (Show a) => a -> Text
showText =
    Text.pack . show

websocketApplication :: ServerState -> WebSockets.ServerApp
websocketApplication server pending
    | WebSockets.requestPath (WebSockets.pendingRequest pending) == "/ws" = do
        connection <- WebSockets.acceptRequest pending
        clientId <- registerClient server connection
        finally
            (clientLoop server connection)
            (removeClient server clientId)
    | otherwise =
        WebSockets.rejectRequest pending "websocket endpoint not found"

clientLoop :: ServerState -> WebSockets.Connection -> IO ()
clientLoop server connection = do
    currentSession server >>= sendServerEvent connection . StateSnapshot
    forever $ do
        rawCommand <-
            WebSockets.receiveData connection
                :: IO LazyByteString.ByteString
        case eitherDecode rawCommand of
            Left err ->
                sendServerEvent connection $
                    CommandFailed
                        CommandFailure
                            { failureCommand = ValidateText ""
                            , failureMessage =
                                "invalid client command JSON: "
                                    <> Text.pack err
                            }
            Right command -> do
                events <- handleClientCommand server command
                let (snapshots, directEvents) = partition isSnapshot events
                traverse_ (sendServerEvent connection) directEvents
                traverse_ (broadcastServerEvent server) snapshots

registerClient :: ServerState -> WebSockets.Connection -> IO Int
registerClient server connection =
    modifyMVar (serverNextClientId server) $ \nextClientId -> do
        let clientId = nextClientId + 1
        modifyMVar_ (serverClients server) $
            pure . ((clientId, connection) :)
        pure (clientId, clientId)

removeClient :: ServerState -> Int -> IO ()
removeClient server clientId =
    modifyMVar_ (serverClients server) $
        pure . filter ((/= clientId) . fst)

broadcastServerEvent :: ServerState -> ServerEvent -> IO ()
broadcastServerEvent server event = do
    clients <- readMVar $ serverClients server
    traverse_ (sendServerEventIgnoringErrors event . snd) clients

sendServerEvent :: WebSockets.Connection -> ServerEvent -> IO ()
sendServerEvent connection event =
    WebSockets.sendTextData connection $ encode event

sendServerEventIgnoringErrors
    :: ServerEvent -> WebSockets.Connection -> IO ()
sendServerEventIgnoringErrors event connection = do
    void
        (try (sendServerEvent connection event) :: IO (Either SomeException ()))

isSnapshot :: ServerEvent -> Bool
isSnapshot = \case
    StateSnapshot{} -> True
    TextValidated{} -> False
    CommandFailed{} -> False

playbackBackendFor :: PlaybackMode -> IO PlaybackBackend
playbackBackendFor = \case
    DryPlayback -> do
        events <- newIORef []
        pure $ dryPlaybackBackend events
    SuperDirtPlayback targetConfig ->
        realTidalPlaybackBackend targetConfig

warpSettings :: ServerConfig -> Warp.Settings
warpSettings config =
    Warp.setHost (fromString $ serverHost config) $
        Warp.setPort (serverPort config) Warp.defaultSettings

parseServerPort :: Maybe String -> Either ServerConfigError Int
parseServerPort Nothing =
    Right 3000
parseServerPort (Just rawPort) =
    case readMaybe rawPort of
        Just port
            | port > 0 && port <= 65535 -> Right port
        _ -> Left $ InvalidServerPort rawPort

parseSlotCapacity :: Maybe String -> Either ServerConfigError Int
parseSlotCapacity Nothing =
    Right 16
parseSlotCapacity (Just rawCapacity) =
    case readMaybe rawCapacity of
        Just capacity
            | capacity >= 0 -> Right capacity
        _ -> Left $ InvalidSlotCapacity rawCapacity

forever :: (Applicative f) => f a -> f b
forever action =
    action *> forever action

module Riptide.Server
    ( ServerState
    , currentSession
    , handleClientCommand
    , newServerState
    ) where

-- \|
-- Module      : Riptide.Server
-- Description : Socket-free server command dispatch.

import Control.Concurrent.MVar
    ( MVar
    , modifyMVar
    , newMVar
    , readMVar
    )
import Data.List (find)
import Data.Text (Text)
import Data.Text qualified as Text
import Riptide.Eval (validateControlPatternWithDefinitions)
import Riptide.Playback
    ( PlaybackBackend
    , activateTrackPlayback
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
import Riptide.Store (saveDefinitions, saveTracks)

data ServerState = ServerState
    { serverSession :: MVar Session
    , serverPlayback :: PlaybackBackend
    , serverStateDir :: FilePath
    }

newServerState
    :: FilePath -> PlaybackBackend -> Session -> IO ServerState
newServerState serverStateDir serverPlayback initialSession = do
    serverSession <- newMVar initialSession
    pure ServerState{..}

currentSession :: ServerState -> IO Session
currentSession =
    readMVar . serverSession

handleClientCommand
    :: ServerState -> ClientCommand -> IO [ServerEvent]
handleClientCommand server command =
    case command of
        ValidateText source ->
            validateText server source
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

module Riptide.ServerSpec
    ( spec
    ) where

import Control.Exception (bracket)
import Data.Aeson (decode)
import Data.ByteString (ByteString)
import Data.ByteString.Lazy qualified as LazyByteString
import Data.IORef (IORef, newIORef, readIORef)
import Data.List (find)
import Data.Text (Text)
import Data.Text qualified as Text
import Network.HTTP.Types
    ( HeaderName
    , methodGet
    , methodOptions
    , statusCode
    )
import Network.Wai
    ( Request (..)
    , defaultRequest
    )
import Network.Wai.Handler.Warp qualified as Warp
import Network.Wai.Test
    ( SRequest (..)
    , SResponse (..)
    , runSession
    , srequest
    )
import Network.WebSockets qualified as WebSockets
import Riptide.Playback
    ( PlaybackEvent (..)
    , dryPlaybackBackend
    )
import Riptide.Protocol
    ( ClientCommand (..)
    , CommandFailure (..)
    , ServerEvent (..)
    , ValidationResult (..)
    )
import Riptide.Server
    ( ServerConfig (..)
    , ServerConfigError (..)
    , ServerState
    , currentSession
    , handleClientCommand
    , newServerState
    , readServerConfigFrom
    , serverApplication
    )
import Riptide.Session
    ( DefinitionBlock (..)
    , DefinitionId (..)
    , Session (..)
    , Slot (..)
    , TextId (..)
    , Track (..)
    , TrackId (..)
    , TrackText (..)
    , activateTrackText
    , addDefinitionBlock
    , addTrack
    , addTrackText
    , applyDefinitionBlock
    , emptySession
    )
import Riptide.Store (loadDefinitions, loadTracks)
import System.Directory
    ( createDirectoryIfMissing
    , getTemporaryDirectory
    , removeFile
    , removePathForcibly
    )
import System.IO (hClose, openTempFile)
import Test.Hspec
    ( Spec
    , describe
    , it
    , shouldBe
    , shouldSatisfy
    )

spec :: Spec
spec = do
    describe "Riptide.Server config" $ do
        it "uses local defaults when the environment is unset" $ do
            config <- readServerConfigFrom $ const $ pure Nothing

            config
                `shouldBe` Right
                    ServerConfig
                        { serverHost = "127.0.0.1"
                        , serverPort = 3000
                        , serverFrontendDir = "frontend/dist"
                        , serverStateDirectory = ".riptide-state"
                        , serverSlotCapacity = 16
                        , serverCorsOrigins = ["*"]
                        }

        it
            "reads configured host, port, frontend dir, state dir, slot capacity, and CORS origins"
            $ do
                config <-
                    readServerConfigFrom $
                        envLookup
                            [ ("RIPTIDE_HOST", "0.0.0.0")
                            , ("RIPTIDE_PORT", "4321")
                            , ("RIPTIDE_FRONTEND_DIR", "dist")
                            , ("RIPTIDE_STATE_DIR", "state")
                            , ("RIPTIDE_SLOT_CAPACITY", "32")
                            ,
                                ( "RIPTIDE_CORS_ORIGINS"
                                , "https://ui.example, http://tailnet.test"
                                )
                            ]

                config
                    `shouldBe` Right
                        ServerConfig
                            { serverHost = "0.0.0.0"
                            , serverPort = 4321
                            , serverFrontendDir = "dist"
                            , serverStateDirectory = "state"
                            , serverSlotCapacity = 32
                            , serverCorsOrigins =
                                [ "https://ui.example"
                                , "http://tailnet.test"
                                ]
                            }

        it "reports an invalid port as a recoverable config error" $ do
            config <-
                readServerConfigFrom $
                    envLookup [("RIPTIDE_PORT", "not-a-port")]

            config `shouldBe` Left (InvalidServerPort "not-a-port")

        it "reports an invalid slot capacity as a recoverable config error" $ do
            config <-
                readServerConfigFrom $
                    envLookup [("RIPTIDE_SLOT_CAPACITY", "not-a-capacity")]

            config `shouldBe` Left (InvalidSlotCapacity "not-a-capacity")

    describe "Riptide.Server command dispatch" $ do
        it "validates basic Tidal text" $
            withServer trackSession $ \server _ _ -> do
                events <- handleClientCommand server $ ValidateText "sound \"bd\""

                events
                    `shouldBe` [ TextValidated $
                                    ValidationSucceeded "sound \"bd\""
                               ]

        it "validates text with applied definitions in scope" $
            withServer sessionWithAppliedDefinition $ \server _ _ -> do
                events <- handleClientCommand server $ ValidateText "kick"

                events `shouldBe` [TextValidated $ ValidationSucceeded "kick"]

        it "activates track text and records dry playback replacement" $
            withServer savedTrackSession $ \server eventsRef _ -> do
                events <-
                    handleClientCommand server $
                        ActivateTrackText trackA textA

                session <- currentSession server
                trackActiveText <$> findTrack trackA session
                    `shouldBe` Just (Just textA)
                events `shouldBe` [StateSnapshot session]
                recorded <- readIORef eventsRef
                playbackEventSlots recorded `shouldBe` [Slot 1]
                playbackEventKinds recorded `shouldBe` ["replace"]

        it "silences track text and records dry playback silence" $
            withServer activeTrackSession $ \server eventsRef _ -> do
                events <- handleClientCommand server $ SilenceTrack trackA

                session <- currentSession server
                trackActiveText <$> findTrack trackA session `shouldBe` Just Nothing
                events `shouldBe` [StateSnapshot session]
                recorded <- readIORef eventsRef
                playbackEventSlots recorded `shouldBe` [Slot 1]
                playbackEventKinds recorded `shouldBe` ["silence"]

        it "saves track text and persists tracks" $
            withServer savedTrackSession $ \server _ stateDir -> do
                events <-
                    handleClientCommand server $
                        SaveTrackText trackA textA "sound \"sn\""

                session <- currentSession server
                sourceFor trackA textA session `shouldBe` Just "sound \"sn\""
                events `shouldBe` [StateSnapshot session]

                loaded <- loadTracks stateDir
                sourceFor trackA textA session{sessionTracks = loaded}
                    `shouldBe` Just "sound \"sn\""

        it "replaces session tracks and definitions from the client" $
            withServer sessionWithCapacity $ \server _ stateDir -> do
                events <- handleClientCommand server $ SetSession clientSession

                session <- currentSession server
                sessionSlotCapacity session `shouldBe` 8
                sessionTracks session `shouldBe` sessionTracks clientSession
                sessionDefinitions session `shouldBe` sessionDefinitions clientSession
                events `shouldBe` [StateSnapshot session]

                loadedTracks <- loadTracks stateDir
                loadedDefinitions <- loadDefinitions stateDir
                loadedTracks `shouldBe` sessionTracks clientSession
                loadedDefinitions `shouldBe` sessionDefinitions clientSession

        it "saves and applies definitions and persists definitions" $
            withServer trackSession $ \server _ stateDir -> do
                saveEvents <-
                    handleClientCommand server $
                        SaveDefinition defsA "shared" "let kick = sound \"bd\""
                saved <- currentSession server

                saveEvents `shouldBe` [StateSnapshot saved]
                blockApplied <$> findDefinition defsA saved `shouldBe` Just ""

                applyEvents <-
                    handleClientCommand server $
                        ApplyDefinition defsA
                applied <- currentSession server

                applyEvents `shouldBe` [StateSnapshot applied]
                blockApplied <$> findDefinition defsA applied
                    `shouldBe` Just "let kick = sound \"bd\""

                loaded <- loadDefinitions stateDir
                blockApplied <$> find ((== defsA) . blockId) loaded
                    `shouldBe` Just "let kick = sound \"bd\""

        it
            "returns CommandFailed and leaves state unchanged on playback failure"
            $ withServer invalidPlaybackSession
            $ \server eventsRef _ -> do
                before <- currentSession server
                events <-
                    handleClientCommand server $
                        ActivateTrackText trackA textA

                after <- currentSession server
                after `shouldBe` before
                events `shouldSatisfy` commandFailed (ActivateTrackText trackA textA)
                readIORef eventsRef >>= (`shouldBe` 0) . length

    describe "Riptide.Server CORS" $ do
        it "answers OPTIONS preflight with CORS headers" $
            withServer corsSession $ \server _ frontendDir -> do
                response <-
                    runCorsRequest
                        ["*"]
                        server
                        frontendDir
                        defaultRequest
                            { requestMethod = methodOptions
                            , requestHeaders =
                                [ ("Origin", "https://foreign.example")
                                ,
                                    ( "Access-Control-Request-Method"
                                    , methodGet
                                    )
                                ]
                            }

                statusCode (simpleStatus response) `shouldBe` 204
                responseHeader "Access-Control-Allow-Origin" response
                    `shouldBe` Just "*"
                responseHeader "Access-Control-Allow-Methods" response
                    `shouldBe` Just "GET, POST, OPTIONS"
                responseHeader "Access-Control-Allow-Headers" response
                    `shouldBe` Just "Content-Type"
                simpleBody response `shouldBe` ""

        it "allows a normal foreign-origin HTTP request by default" $
            withServer corsSession $ \server _ frontendDir -> do
                response <-
                    runCorsRequest
                        ["*"]
                        server
                        frontendDir
                        defaultRequest
                            { requestMethod = methodGet
                            , requestHeaders =
                                [("Origin", "https://foreign.example")]
                            }

                responseHeader "Access-Control-Allow-Origin" response
                    `shouldBe` Just "*"

        it "accepts websocket clients with a foreign Origin" $
            withServer corsSession $ \server _ frontendDir ->
                Warp.testWithApplication
                    (pure $ serverApplication ["*"] server frontendDir)
                    $ \port -> do
                        rawMessage <-
                            WebSockets.runClientWith
                                "127.0.0.1"
                                port
                                "/ws"
                                WebSockets.defaultConnectionOptions
                                [("Origin", "https://foreign.example")]
                                WebSockets.receiveData

                        decode rawMessage
                            `shouldBe` Just (StateSnapshot corsSession)

withServer
    :: Session
    -> (ServerState -> IORef [PlaybackEvent] -> FilePath -> IO a)
    -> IO a
withServer session action =
    withTempDir $ \stateDir -> do
        events <- newIORef []
        server <- newServerState stateDir (dryPlaybackBackend events) session
        action server events stateDir

commandFailed :: ClientCommand -> [ServerEvent] -> Bool
commandFailed command events =
    case events of
        [ CommandFailed
                CommandFailure
                    { failureCommand = failedCommand
                    , failureMessage = message
                    }
            ] ->
                failedCommand == command && not (Text.null message)
        _ -> False

trackA :: TrackId
trackA = TrackId "track-a"

textA :: TextId
textA = TextId "text-a"

defsA :: DefinitionId
defsA = DefinitionId "defs-a"

trackSession :: Session
trackSession =
    case addTrack trackA "track a" $ emptySession 4 of
        Just session -> session
        Nothing -> emptySession 4

savedTrackSession :: Session
savedTrackSession =
    trackSession
        & addTrackText trackA textA "sound \"bd\""

activeTrackSession :: Session
activeTrackSession =
    savedTrackSession
        & activateTrackText trackA textA

invalidPlaybackSession :: Session
invalidPlaybackSession =
    trackSession
        & addTrackText trackA textA "missingDefinition"

sessionWithAppliedDefinition :: Session
sessionWithAppliedDefinition =
    trackSession
        & addDefinitionBlock defsA "shared" "let kick = sound \"bd\""
        & applyDefinitionBlock defsA

sessionWithCapacity :: Session
sessionWithCapacity =
    emptySession 8

clientSession :: Session
clientSession =
    Session
        { sessionSlotCapacity = 2
        , sessionTracks =
            [ Track
                { trackId = trackA
                , trackName = "client track"
                , trackSlot = Slot 3
                , trackTexts =
                    [ TrackText
                        { trackTextId = textA
                        , trackTextSource = "sound \"bd\""
                        }
                    ]
                , trackActiveText = Just textA
                , trackSelectedText = Just textA
                }
            ]
        , sessionDefinitions =
            [ DefinitionBlock
                { blockId = defsA
                , blockName = "client defs"
                , blockCode = "let kick = sound \"bd\""
                , blockApplied = "let kick = sound \"bd\""
                }
            ]
        }

corsSession :: Session
corsSession =
    emptySession 4

findTrack :: TrackId -> Session -> Maybe Track
findTrack ident session =
    find ((== ident) . trackId) (sessionTracks session)

findDefinition :: DefinitionId -> Session -> Maybe DefinitionBlock
findDefinition ident session =
    find ((== ident) . blockId) (sessionDefinitions session)

sourceFor :: TrackId -> TextId -> Session -> Maybe Text
sourceFor trackIdent textIdent session = do
    track <- findTrack trackIdent session
    trackTextSource
        <$> find ((== textIdent) . trackTextId) (trackTexts track)

playbackEventSlots :: [PlaybackEvent] -> [Slot]
playbackEventSlots events =
    [slot | event <- events, let slot = playbackEventSlot event]

playbackEventKinds :: [PlaybackEvent] -> [String]
playbackEventKinds events =
    [ case event of
        PlaybackReplace{} -> "replace"
        PlaybackSilence{} -> "silence"
    | event <- events
    ]

playbackEventSlot :: PlaybackEvent -> Slot
playbackEventSlot = \case
    PlaybackReplace slot _ -> slot
    PlaybackSilence slot -> slot

withTempDir :: (FilePath -> IO a) -> IO a
withTempDir =
    bracket acquire removePathForcibly
  where
    acquire = do
        tmp <- getTemporaryDirectory
        (path, handle) <- openTempFile tmp "riptide-server"
        hClose handle
        removeFile path
        createDirectoryIfMissing True path
        pure path

(&) :: a -> (a -> b) -> b
(&) value f = f value

envLookup :: [(String, String)] -> String -> IO (Maybe String)
envLookup vars name =
    pure $ lookup name vars

runCorsRequest
    :: [String] -> ServerState -> FilePath -> Request -> IO SResponse
runCorsRequest origins server frontendDir request =
    runSession
        (srequest $ SRequest request LazyByteString.empty)
        (serverApplication origins server frontendDir)

responseHeader :: HeaderName -> SResponse -> Maybe ByteString
responseHeader name response =
    lookup name $ simpleHeaders response

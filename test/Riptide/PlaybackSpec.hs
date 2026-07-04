module Riptide.PlaybackSpec
    ( spec
    ) where

import Data.IORef (newIORef, readIORef)
import Data.Text (Text)
import Riptide.Playback
    ( PlaybackError (..)
    , PlaybackEvent (..)
    , activateTrackPlayback
    , dryPlaybackBackend
    , silenceTrackPlayback
    )
import Riptide.Session
    ( DefinitionId (..)
    , Session (..)
    , Slot (..)
    , TextId (..)
    , Track (..)
    , TrackId (..)
    , activateTrackText
    , addDefinitionBlock
    , addTrack
    , addTrackText
    , applyDefinitionBlock
    , emptySession
    , silenceTrack
    )
import Test.Hspec
    ( Spec
    , describe
    , expectationFailure
    , it
    , shouldBe
    )

spec :: Spec
spec =
    describe "Riptide.Playback" $ do
        it "activates active track text by replacing the track slot" $ do
            events <- newIORef []
            let backend = dryPlaybackBackend events

            result <-
                activateTrackPlayback
                    backend
                    (activeSession "sound \"bd\"")
                    trackA

            result `shouldBe` Right ()
            recorded <- readIORef events
            playbackEventSlots recorded `shouldBe` [Slot 1]
            playbackEventKinds recorded `shouldBe` ["replace"]

        it "interprets active track text with applied definitions" $ do
            events <- newIORef []
            let backend = dryPlaybackBackend events
                session =
                    activeSession "kick"
                        & addDefinitionBlock
                            (DefinitionId "defs-a")
                            "defs"
                            "let kick = sound \"bd\""
                        & applyDefinitionBlock (DefinitionId "defs-a")

            result <- activateTrackPlayback backend session trackA

            result `shouldBe` Right ()
            recorded <- readIORef events
            playbackEventKinds recorded `shouldBe` ["replace"]

        it "silences a track by silencing the track slot" $ do
            events <- newIORef []
            let backend = dryPlaybackBackend events

            result <-
                silenceTrackPlayback
                    backend
                    (activeSession "sound \"bd\"")
                    trackA

            result `shouldBe` Right ()
            recorded <- readIORef events
            playbackEventSlots recorded `shouldBe` [Slot 1]
            playbackEventKinds recorded `shouldBe` ["silence"]

        it "returns recoverable errors without recording playback events" $ do
            missingTrackEvents <- newIORef []
            missingActiveEvents <- newIORef []
            missingTextEvents <- newIORef []
            interpretEvents <- newIORef []

            missingTrack <-
                activateTrackPlayback
                    (dryPlaybackBackend missingTrackEvents)
                    (emptySession 4)
                    trackA
            missingActive <-
                activateTrackPlayback
                    (dryPlaybackBackend missingActiveEvents)
                    trackSession
                    trackA
            missingText <-
                activateTrackPlayback
                    (dryPlaybackBackend missingTextEvents)
                    trackWithDanglingActiveText
                    trackA
            interpretFailure <-
                activateTrackPlayback
                    (dryPlaybackBackend interpretEvents)
                    (activeSession "missingDefinition")
                    trackA

            missingTrack `shouldBe` Left (PlaybackTrackMissing trackA)
            missingActive `shouldBe` Left (PlaybackActiveTextMissing trackA)
            missingText
                `shouldBe` Left (PlaybackTextMissing trackA (TextId "ghost"))
            case interpretFailure of
                Left (PlaybackInterpretError _) -> pure ()
                other ->
                    expectationFailure $
                        "expected interpret failure, got " <> show other

            eventCounts <-
                fmap length
                    <$> traverse
                        readIORef
                        [ missingTrackEvents
                        , missingActiveEvents
                        , missingTextEvents
                        , interpretEvents
                        ]
            eventCounts `shouldBe` replicate 4 0

        it "returns recoverable errors when silencing a missing track" $ do
            events <- newIORef []

            result <-
                silenceTrackPlayback
                    (dryPlaybackBackend events)
                    (emptySession 4)
                    trackA

            result `shouldBe` Left (PlaybackTrackMissing trackA)
            readIORef events >>= (`shouldBe` 0) . length

trackA :: TrackId
trackA = TrackId "track-a"

trackSession :: Session
trackSession =
    case addTrack trackA "track a" $ emptySession 4 of
        Just session -> session
        Nothing -> emptySession 4

activeSession :: Text -> Session
activeSession source =
    trackSession
        & addTrackText trackA textA source
        & activateTrackText trackA textA

trackWithDanglingActiveText :: Session
trackWithDanglingActiveText =
    (silenceTrack trackA $ activeSession "sound \"bd\"")
        { sessionTracks =
            case sessionTracks trackSession of
                track : _ ->
                    [ track
                        { trackActiveText = Just $ TextId "ghost"
                        }
                    ]
                [] -> []
        }

textA :: TextId
textA = TextId "text-a"

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

(&) :: a -> (a -> b) -> b
(&) value f = f value

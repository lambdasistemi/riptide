module Riptide.Playback
    ( PlaybackBackend (..)
    , PlaybackConfigError (..)
    , PlaybackError (..)
    , PlaybackEvent (..)
    , PlaybackMode (..)
    , SuperDirtTargetConfig (..)
    , activateTrackPlayback
    , dryPlaybackBackend
    , readPlaybackMode
    , readPlaybackModeFrom
    , realTidalPlaybackBackend
    , silenceTrackPlayback
    , superDirtTargetFor
    ) where

-- \|
-- Module      : Riptide.Playback
-- Description : Audio-free playback boundary between sessions and evaluation.
-- Copyright   : (c) Paolo Veronelli, 2026
-- License     : BSD-3-Clause

import Data.IORef (IORef, modifyIORef')
import Data.List (find)
import Data.Maybe (fromMaybe)
import Data.Text qualified as Text
import Riptide.Eval (interpretControlPatternWithDefinitions)
import Riptide.Session
    ( DefinitionBlock (..)
    , Session (..)
    , Slot (..)
    , TextId
    , Track (..)
    , TrackId
    , TrackText (..)
    )
import Sound.Tidal.Config (defaultConfig)
import Sound.Tidal.Context (ControlPattern)
import Sound.Tidal.ID (ID (..))
import Sound.Tidal.Stream
    ( startTidal
    , streamReplace
    , streamSilence
    )
import Sound.Tidal.Stream.Target (superdirtTarget)
import Sound.Tidal.Stream.Types (Target, oAddress, oPort)
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

data PlaybackBackend = PlaybackBackend
    { replaceSlot :: Slot -> ControlPattern -> IO ()
    , silenceSlot :: Slot -> IO ()
    }

data SuperDirtTargetConfig = SuperDirtTargetConfig
    { superDirtHost :: String
    , superDirtPort :: Int
    }
    deriving stock (Show, Eq)

data PlaybackMode
    = DryPlayback
    | SuperDirtPlayback SuperDirtTargetConfig
    deriving stock (Show, Eq)

newtype PlaybackConfigError
    = InvalidSuperDirtPort String
    deriving stock (Show, Eq)

data PlaybackError
    = PlaybackTrackMissing TrackId
    | PlaybackActiveTextMissing TrackId
    | PlaybackTextMissing TrackId TextId
    | PlaybackInterpretError String
    deriving stock (Show, Eq)

data PlaybackEvent
    = PlaybackReplace Slot ControlPattern
    | PlaybackSilence Slot

activateTrackPlayback
    :: PlaybackBackend
    -> Session
    -> TrackId
    -> IO (Either PlaybackError ())
activateTrackPlayback backend session trackIdent =
    case findTrack trackIdent session of
        Nothing ->
            pure $ Left $ PlaybackTrackMissing trackIdent
        Just track ->
            case trackActiveText track of
                Nothing ->
                    pure $ Left $ PlaybackActiveTextMissing trackIdent
                Just textIdent ->
                    activateTrackTextPlayback backend session track textIdent

silenceTrackPlayback
    :: PlaybackBackend
    -> Session
    -> TrackId
    -> IO (Either PlaybackError ())
silenceTrackPlayback backend session trackIdent =
    case findTrack trackIdent session of
        Nothing ->
            pure $ Left $ PlaybackTrackMissing trackIdent
        Just track -> do
            silenceSlot backend (trackSlot track)
            pure $ Right ()

dryPlaybackBackend :: IORef [PlaybackEvent] -> PlaybackBackend
dryPlaybackBackend events =
    PlaybackBackend
        { replaceSlot = \slot patternValue ->
            modifyIORef' events (<> [PlaybackReplace slot patternValue])
        , silenceSlot = \slot ->
            modifyIORef' events (<> [PlaybackSilence slot])
        }

readPlaybackMode :: IO (Either PlaybackConfigError PlaybackMode)
readPlaybackMode = readPlaybackModeFrom lookupEnv

readPlaybackModeFrom
    :: (String -> IO (Maybe String))
    -> IO (Either PlaybackConfigError PlaybackMode)
readPlaybackModeFrom lookupVar = do
    configuredHost <- lookupVar "RIPTIDE_SUPERDIRT_HOST"
    configuredPort <- lookupVar "RIPTIDE_SUPERDIRT_PORT"
    pure $ playbackModeFrom configuredHost configuredPort

superDirtTargetFor :: SuperDirtTargetConfig -> Target
superDirtTargetFor SuperDirtTargetConfig{..} =
    superdirtTarget
        { oAddress = superDirtHost
        , oPort = superDirtPort
        }

realTidalPlaybackBackend
    :: SuperDirtTargetConfig -> IO PlaybackBackend
realTidalPlaybackBackend targetConfig = do
    stream <- startTidal (superDirtTargetFor targetConfig) defaultConfig
    pure
        PlaybackBackend
            { replaceSlot = streamReplace stream . slotId
            , silenceSlot = streamSilence stream . slotId
            }

activateTrackTextPlayback
    :: PlaybackBackend
    -> Session
    -> Track
    -> TextId
    -> IO (Either PlaybackError ())
activateTrackTextPlayback backend session track textIdent =
    case findTrackText textIdent track of
        Nothing ->
            pure $
                Left $
                    PlaybackTextMissing (trackId track) textIdent
        Just trackText -> do
            result <-
                interpretControlPatternWithDefinitions
                    (appliedDefinitions session)
                    (Text.unpack $ trackTextSource trackText)
            case result of
                Left err ->
                    pure $ Left $ PlaybackInterpretError $ show err
                Right patternValue -> do
                    replaceSlot backend (trackSlot track) patternValue
                    pure $ Right ()

findTrack :: TrackId -> Session -> Maybe Track
findTrack trackIdent session =
    find ((== trackIdent) . trackId) (sessionTracks session)

findTrackText :: TextId -> Track -> Maybe TrackText
findTrackText textIdent track =
    find ((== textIdent) . trackTextId) (trackTexts track)

appliedDefinitions :: Session -> [String]
appliedDefinitions session =
    Text.unpack . blockApplied
        <$> filter (not . Text.null . blockApplied) (sessionDefinitions session)

playbackModeFrom
    :: Maybe String
    -> Maybe String
    -> Either PlaybackConfigError PlaybackMode
playbackModeFrom Nothing Nothing =
    Right DryPlayback
playbackModeFrom configuredHost configuredPort = do
    port <- parseSuperDirtPort configuredPort
    Right $
        SuperDirtPlayback $
            SuperDirtTargetConfig
                { superDirtHost = fromMaybe "127.0.0.1" configuredHost
                , superDirtPort = port
                }

parseSuperDirtPort :: Maybe String -> Either PlaybackConfigError Int
parseSuperDirtPort Nothing =
    Right 57120
parseSuperDirtPort (Just rawPort) =
    case readMaybe rawPort of
        Just port -> Right port
        Nothing -> Left $ InvalidSuperDirtPort rawPort

slotId :: Slot -> ID
slotId (Slot slotNumber) =
    ID $ "d" <> show slotNumber

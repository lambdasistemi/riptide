module Riptide.Playback
    ( PlaybackBackend (..)
    , PlaybackError (..)
    , PlaybackEvent (..)
    , activateTrackPlayback
    , dryPlaybackBackend
    , silenceTrackPlayback
    ) where

-- \|
-- Module      : Riptide.Playback
-- Description : Audio-free playback boundary between sessions and evaluation.
-- Copyright   : (c) Paolo Veronelli, 2026
-- License     : BSD-3-Clause

import Data.IORef (IORef, modifyIORef')
import Data.List (find)
import Data.Text qualified as Text
import Riptide.Eval (interpretControlPatternWithDefinitions)
import Riptide.Session
    ( DefinitionBlock (..)
    , Session (..)
    , Slot
    , TextId
    , Track (..)
    , TrackId
    , TrackText (..)
    )
import Sound.Tidal.Context (ControlPattern)

data PlaybackBackend = PlaybackBackend
    { replaceSlot :: Slot -> ControlPattern -> IO ()
    , silenceSlot :: Slot -> IO ()
    }

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

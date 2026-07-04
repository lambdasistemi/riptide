module Riptide.Session
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
    , editDefinitionBlock
    , editTrackText
    , emptySession
    , removeDefinitionBlock
    , removeTrack
    , removeTrackText
    , saveTrackText
    , selectTrackText
    , silenceTrack
    ) where

{- |
Module      : Riptide.Session
Description : Pure session state and reducers for riptide.
Copyright   : (c) Paolo Veronelli, 2026
License     : BSD-3-Clause

This module owns the pure backend session domain. Tracks receive hidden Tidal
slots from a bounded pool, while performer-facing state is expressed in opaque
track, text, and definition identifiers.
-}

import Data.List (find)
import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)

-- | Opaque track identifier.
newtype TrackId = TrackId Text
    deriving stock (Show, Eq, Ord, Generic)

instance FromJSON TrackId

instance ToJSON TrackId

-- | Opaque track text/cell identifier.
newtype TextId = TextId Text
    deriving stock (Show, Eq, Ord, Generic)

instance FromJSON TextId

instance ToJSON TextId

-- | Opaque definition block identifier.
newtype DefinitionId = DefinitionId Text
    deriving stock (Show, Eq, Ord, Generic)

instance FromJSON DefinitionId

instance ToJSON DefinitionId

-- | Hidden Tidal slot number, corresponding to @d1@ through @dN@.
newtype Slot = Slot Int
    deriving stock (Show, Eq, Ord, Generic)

instance FromJSON Slot

instance ToJSON Slot

-- | One editable Tidal source text on a track.
data TrackText = TrackText
    { trackTextId :: TextId
    , trackTextSource :: Text
    }
    deriving stock (Show, Eq, Generic)

instance FromJSON TrackText

instance ToJSON TrackText

-- | A launch-grid track with one hidden slot and cell state.
data Track = Track
    { trackId :: TrackId
    , trackName :: Text
    , trackSlot :: Slot
    , trackTexts :: [TrackText]
    , trackActiveText :: Maybe TextId
    , trackSelectedText :: Maybe TextId
    }
    deriving stock (Show, Eq, Generic)

instance FromJSON Track

instance ToJSON Track

-- | Shared definition block with editor and applied code.
data DefinitionBlock = DefinitionBlock
    { blockId :: DefinitionId
    , blockName :: Text
    , blockCode :: Text
    , blockApplied :: Text
    }
    deriving stock (Show, Eq, Generic)

instance FromJSON DefinitionBlock

instance ToJSON DefinitionBlock

-- | Pure backend session state.
data Session = Session
    { sessionSlotCapacity :: Int
    , sessionTracks :: [Track]
    , sessionDefinitions :: [DefinitionBlock]
    }
    deriving stock (Show, Eq, Generic)

instance FromJSON Session

instance ToJSON Session

-- | Create an empty session with a bounded hidden slot pool.
emptySession :: Int -> Session
emptySession slotCapacity =
    Session
        { sessionSlotCapacity = max 0 slotCapacity
        , sessionTracks = []
        , sessionDefinitions = []
        }

-- | Add a track if the ID is fresh and a hidden slot is available.
addTrack :: TrackId -> Text -> Session -> Maybe Session
addTrack ident name session
    | any ((== ident) . trackId) (sessionTracks session) = Nothing
    | otherwise =
        case nextSlot session of
            Nothing -> Nothing
            Just slot ->
                Just
                    session
                        { sessionTracks =
                            sessionTracks session
                                <> [emptyTrack ident name slot]
                        }

-- | Remove a track, releasing its hidden slot for future tracks.
removeTrack :: TrackId -> Session -> Session
removeTrack ident session =
    session
        { sessionTracks =
            filter ((/= ident) . trackId) (sessionTracks session)
        }

-- | Add a text/cell to an existing track when the text ID is fresh.
addTrackText :: TrackId -> TextId -> Text -> Session -> Session
addTrackText trackIdent textIdent source =
    overTrack trackIdent addText
  where
    addText track
        | any ((== textIdent) . trackTextId) (trackTexts track) = track
        | otherwise =
            track
                { trackTexts =
                    trackTexts track
                        <> [TrackText textIdent source]
                }

-- | Remove a text/cell and clear active or selected references to it.
removeTrackText :: TrackId -> TextId -> Session -> Session
removeTrackText trackIdent textIdent =
    overTrack trackIdent removeText
  where
    removeText track =
        track
            { trackTexts =
                filter ((/= textIdent) . trackTextId) (trackTexts track)
            , trackActiveText =
                clearReference textIdent (trackActiveText track)
            , trackSelectedText =
                clearReference textIdent (trackSelectedText track)
            }

-- | Edit a track text/cell source buffer.
editTrackText :: TrackId -> TextId -> Text -> Session -> Session
editTrackText = setTrackTextSource

-- | Save a track text/cell source.
saveTrackText :: TrackId -> TextId -> Text -> Session -> Session
saveTrackText = setTrackTextSource

-- | Select the text/cell the score should launch without activating it.
selectTrackText :: TrackId -> TextId -> Session -> Session
selectTrackText trackIdent textIdent =
    overTrack trackIdent selectText
  where
    selectText track
        | trackHasText textIdent track =
            track{trackSelectedText = Just textIdent}
        | otherwise = track

-- | Toggle a text/cell active, arming it when it starts.
activateTrackText :: TrackId -> TextId -> Session -> Session
activateTrackText trackIdent textIdent =
    overTrack trackIdent activateText
  where
    activateText track
        | not $ trackHasText textIdent track = track
        | trackActiveText track == Just textIdent =
            track{trackActiveText = Nothing}
        | otherwise =
            track
                { trackActiveText = Just textIdent
                , trackSelectedText = Just textIdent
                }

-- | Silence a track without changing its selected text/cell.
silenceTrack :: TrackId -> Session -> Session
silenceTrack trackIdent =
    overTrack trackIdent $ \track -> track{trackActiveText = Nothing}

-- | Add a definition block with empty applied code.
addDefinitionBlock
    :: DefinitionId
    -> Text
    -> Text
    -> Session
    -> Session
addDefinitionBlock ident name code session
    | any ((== ident) . blockId) (sessionDefinitions session) = session
    | otherwise =
        session
            { sessionDefinitions =
                sessionDefinitions session
                    <> [DefinitionBlock ident name code ""]
            }

-- | Edit a definition block's name and editor code.
editDefinitionBlock
    :: DefinitionId
    -> Text
    -> Text
    -> Session
    -> Session
editDefinitionBlock ident name code =
    overDefinition ident $ \block ->
        block{blockName = name, blockCode = code}

-- | Apply a definition block by copying editor code to applied code.
applyDefinitionBlock :: DefinitionId -> Session -> Session
applyDefinitionBlock ident =
    overDefinition ident $ \block ->
        block{blockApplied = blockCode block}

-- | Remove a definition block.
removeDefinitionBlock :: DefinitionId -> Session -> Session
removeDefinitionBlock ident session =
    session
        { sessionDefinitions =
            filter ((/= ident) . blockId) (sessionDefinitions session)
        }

emptyTrack :: TrackId -> Text -> Slot -> Track
emptyTrack ident name slot =
    Track
        { trackId = ident
        , trackName = name
        , trackSlot = slot
        , trackTexts = []
        , trackActiveText = Nothing
        , trackSelectedText = Nothing
        }

nextSlot :: Session -> Maybe Slot
nextSlot Session{..} =
    find (`notElem` usedSlots) allSlots
  where
    allSlots = Slot <$> [1 .. sessionSlotCapacity]
    usedSlots = trackSlot <$> sessionTracks

overTrack :: TrackId -> (Track -> Track) -> Session -> Session
overTrack ident f session =
    session
        { sessionTracks =
            fmap updateTrack (sessionTracks session)
        }
  where
    updateTrack track
        | trackId track == ident = f track
        | otherwise = track

overDefinition
    :: DefinitionId
    -> (DefinitionBlock -> DefinitionBlock)
    -> Session
    -> Session
overDefinition ident f session =
    session
        { sessionDefinitions =
            fmap updateBlock (sessionDefinitions session)
        }
  where
    updateBlock block
        | blockId block == ident = f block
        | otherwise = block

setTrackTextSource :: TrackId -> TextId -> Text -> Session -> Session
setTrackTextSource trackIdent textIdent source =
    overTrack trackIdent setSource
  where
    setSource track =
        track
            { trackTexts = fmap updateText (trackTexts track)
            }
    updateText trackText
        | trackTextId trackText == textIdent =
            trackText{trackTextSource = source}
        | otherwise = trackText

trackHasText :: TextId -> Track -> Bool
trackHasText textIdent =
    any ((== textIdent) . trackTextId) . trackTexts

clearReference :: Eq a => a -> Maybe a -> Maybe a
clearReference ident ref
    | ref == Just ident = Nothing
    | otherwise = ref

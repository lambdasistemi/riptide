module Riptide.ImportExport
  ( ExportedBlock
  , ExportedCell
  , ExportedSong
  , ExportedToolbox
  , ExportedTrack
  , exportSong
  , exportToolbox
  , importSong
  , importToolbox
  ) where

import Prelude

import Data.Array as Array
import Data.FoldableWithIndex (foldlWithIndex)
import Data.Maybe (Maybe(..), fromMaybe)
import Riptide.Helpers (normalizeScore)
import Riptide.Model (App, Block, BlockId, Cell, CellId, Page(..), Song, SongId, Toolbox, ToolboxId, Track, TrackId)
import Riptide.Validation (valid)

type ExportedSong =
  { riptideSong :: Int
  , name :: String
  , tracks :: Array ExportedTrack
  }

type ExportedTrack =
  { name :: String
  , hue :: Maybe Int
  , vol :: Maybe Int
  , flt :: Maybe Int
  , dly :: Maybe Int
  , active :: Maybe String
  , selected :: Maybe String
  , score :: Array Boolean
  , cells :: Array ExportedCell
  }

type ExportedCell =
  { id :: String
  , code :: String
  }

type ExportedToolbox =
  { riptideToolbox :: Int
  , name :: String
  , blocks :: Array ExportedBlock
  }

type ExportedBlock =
  { name :: String
  , code :: String
  }

exportSong :: Song -> ExportedSong
exportSong song =
  { riptideSong: 1
  , name: song.name
  , tracks:
      map
        ( \track ->
            { name: track.name
            , hue: Just track.hue
            , vol: Just track.vol
            , flt: Just track.flt
            , dly: Just track.dly
            , active: track.active
            , selected: track.selected
            , score: normalizeScore track.score
            , cells: map (\cell -> { id: cell.id, code: cell.code }) track.cells
            }
        )
        song.tracks
  }

exportToolbox :: Toolbox -> ExportedToolbox
exportToolbox toolbox =
  { riptideToolbox: 1
  , name: toolbox.name
  , blocks: map (\block -> { name: block.name, code: block.code }) toolbox.blocks
  }

importSong :: SongId -> Array TrackId -> Array CellId -> ExportedSong -> App -> App
importSong songId trackIds cellIds exported app =
  let
    rebuilt = rebuildTracks trackIds cellIds exported.tracks

    song =
      { id: songId
      , name: exported.name
      , tracks: rebuilt.tracks
      }
  in
    app
      { songs = app.songs <> [ song ]
      , currentSongId = Just songId
      , page = SongPage
      , toast = Just ("Imported song " <> exported.name)
      }

importToolbox :: ToolboxId -> Array BlockId -> ExportedToolbox -> App -> App
importToolbox toolboxId blockIds exported app =
  let
    toolbox =
      { id: toolboxId
      , name: exported.name
      , blocks: Array.mapWithIndex (importBlock blockIds) exported.blocks
      }
  in
    app
      { toolboxes = app.toolboxes <> [ toolbox ]
      , currentToolboxId = Just toolboxId
      , page = DefsPage
      , toast = Just ("Imported toolbox " <> exported.name)
      }

type RebuiltTracks =
  { tracks :: Array Track
  , nextCell :: Int
  }

rebuildTracks :: Array TrackId -> Array CellId -> Array ExportedTrack -> RebuiltTracks
rebuildTracks trackIds cellIds =
  foldlWithIndex step { tracks: [], nextCell: 0 }
  where
  step ix acc source =
    let
      trackId = idAt "track-import-" ix trackIds
      rebuiltCells = Array.mapWithIndex (importCell acc.nextCell cellIds) source.cells
      cellMap = Array.mapWithIndex (\cellIx cell -> { old: cell.id, new: idAt "cell-import-" (acc.nextCell + cellIx) cellIds }) source.cells
      track =
        { id: trackId
        , name: source.name
        , hue: fromMaybe 200 source.hue
        , vol: fromMaybe 80 source.vol
        , flt: fromMaybe 100 source.flt
        , dly: fromMaybe 0 source.dly
        , active: remapMaybe cellMap source.active
        , selected: remapMaybe cellMap source.selected
        , score: normalizeScore source.score
        , cells: rebuiltCells
        }
    in
      { tracks: acc.tracks <> [ track ], nextCell: acc.nextCell + Array.length source.cells }

importCell :: Int -> Array CellId -> Int -> ExportedCell -> Cell
importCell offset cellIds ix cell =
  { id: idAt "cell-import-" (offset + ix) cellIds
  , code: cell.code
  }

importBlock :: Array BlockId -> Int -> ExportedBlock -> Block
importBlock blockIds ix block =
  { id: idAt "block-import-" ix blockIds
  , name: block.name
  , code: block.code
  , applied: if (valid block.code).valid then block.code else ""
  }

remapMaybe :: Array { old :: String, new :: String } -> Maybe String -> Maybe String
remapMaybe mapping value =
  value >>= \old -> map _.new (Array.find (_.old >>> (_ == old)) mapping)

idAt :: String -> Int -> Array String -> String
idAt prefix ix ids =
  fromMaybe (prefix <> show (ix + 1)) (Array.index ids ix)

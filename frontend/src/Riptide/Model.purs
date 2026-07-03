module Riptide.Model
  ( App
  , Block
  , BlockId
  , Cell
  , CellId
  , DragState
  , DropTarget
  , EditingTarget
  , Page(..)
  , PaintState
  , Song
  , SongId
  , Toolbox
  , ToolboxId
  , Track
  , TrackId
  , defaultApp
  , defaultBlock
  , defaultCell
  , defaultSong
  , defaultToolbox
  , defaultTrack
  , totalBars
  ) where

import Prelude

import Data.Maybe (Maybe(..))

totalBars :: Int
totalBars = 16

type SongId = String
type TrackId = String
type CellId = String
type ToolboxId = String
type BlockId = String

data Page
  = SongPage
  | DefsPage

derive instance eqPage :: Eq Page

instance showPage :: Show Page where
  show SongPage = "song"
  show DefsPage = "defs"

type App =
  { page :: Page
  , engine :: Boolean
  , songs :: Array Song
  , currentSongId :: Maybe SongId
  , toolboxes :: Array Toolbox
  , currentToolboxId :: Maybe ToolboxId
  , playing :: Boolean
  , playhead :: Number
  , loopStart :: Int
  , loopEnd :: Int
  , loopOn :: Boolean
  , hoverCell :: Maybe CellId
  , focusCell :: Maybe CellId
  , confirm :: Maybe String
  , editing :: Maybe EditingTarget
  , drag :: Maybe DragState
  , over :: Maybe DropTarget
  , paint :: Maybe PaintState
  , toast :: Maybe String
  , songRailOpen :: Boolean
  , toolboxRailOpen :: Boolean
  , scoreHeight :: Int
  , resizing :: Boolean
  }

type Song =
  { id :: SongId
  , name :: String
  , tracks :: Array Track
  }

type Track =
  { id :: TrackId
  , name :: String
  , hue :: Int
  , vol :: Int
  , flt :: Int
  , dly :: Int
  , active :: Maybe CellId
  , selected :: Maybe CellId
  , score :: Array Boolean
  , cells :: Array Cell
  }

type Cell =
  { id :: CellId
  , code :: String
  }

type Toolbox =
  { id :: ToolboxId
  , name :: String
  , blocks :: Array Block
  }

type Block =
  { id :: BlockId
  , name :: String
  , code :: String
  , applied :: String
  }

type EditingTarget =
  { kind :: String
  , id :: String
  }

type DragState =
  { kind :: String
  , trackId :: TrackId
  , cellId :: Maybe CellId
  }

type DropTarget =
  { kind :: String
  , id :: String
  }

type PaintState =
  { trackId :: TrackId
  , bar :: Int
  , paintVal :: Boolean
  }

defaultApp :: App
defaultApp =
  { page: SongPage
  , engine: true
  , songs: []
  , currentSongId: Nothing
  , toolboxes: []
  , currentToolboxId: Nothing
  , playing: true
  , playhead: 2.35
  , loopStart: 0
  , loopEnd: 12
  , loopOn: true
  , hoverCell: Nothing
  , focusCell: Nothing
  , confirm: Nothing
  , editing: Nothing
  , drag: Nothing
  , over: Nothing
  , paint: Nothing
  , toast: Nothing
  , songRailOpen: true
  , toolboxRailOpen: true
  , scoreHeight: 300
  , resizing: false
  }

defaultSong :: SongId -> String -> Song
defaultSong id name =
  { id
  , name
  , tracks: []
  }

defaultTrack :: TrackId -> String -> Track
defaultTrack id name =
  { id
  , name
  , hue: 200
  , vol: 80
  , flt: 100
  , dly: 0
  , active: Nothing
  , selected: Nothing
  , score: emptyScore
  , cells: []
  }

defaultCell :: CellId -> Cell
defaultCell id =
  { id
  , code: ""
  }

defaultToolbox :: ToolboxId -> String -> Toolbox
defaultToolbox id name =
  { id
  , name
  , blocks: []
  }

defaultBlock :: BlockId -> String -> Block
defaultBlock id name =
  { id
  , name
  , code: ""
  , applied: ""
  }

emptyScore :: Array Boolean
emptyScore =
  [ false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  ]

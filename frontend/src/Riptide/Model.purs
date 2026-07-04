module Riptide.Model
  ( App
  , Block
  , BlockId
  , Cell
  , CellId
  , ConnectionState(..)
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
  , canUseBackend
  , connectionLabel
  , totalBars
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Riptide.Validation (AuthoritativeValidation)
import Riptide.WebSocket (WebSocketClient)

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

data ConnectionState
  = Connecting
  | Connected
  | Disconnected
  | ConnectionError String

derive instance eqConnectionState :: Eq ConnectionState

instance showConnectionState :: Show ConnectionState where
  show = case _ of
    Connecting -> "connecting"
    Connected -> "connected"
    Disconnected -> "disconnected"
    ConnectionError message -> "error: " <> message

connectionLabel :: ConnectionState -> String
connectionLabel = case _ of
  Connecting -> "engine connecting"
  Connected -> "engine connected"
  Disconnected -> "engine offline"
  ConnectionError _ -> "engine error"

canUseBackend :: ConnectionState -> Boolean
canUseBackend = case _ of
  Connected -> true
  _ -> false

type App =
  { page :: Page
  , engine :: Boolean
  , connection :: ConnectionState
  , websocket :: Maybe WebSocketClient
  , backendValidation :: Array AuthoritativeValidation
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
  , confirmToken :: Int
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
  , trackId :: TrackId
  , cellId :: Maybe CellId
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
  , connection: Disconnected
  , websocket: Nothing
  , backendValidation: []
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
  , confirmToken: 0
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

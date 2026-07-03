module Riptide.App
  ( component
  ) where

import Prelude

import Data.Array as Array
import Data.Int as Int
import Data.Maybe (Maybe(..))
import Data.Traversable (traverse)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Riptide.Action (ControlKey)
import Riptide.Model (App, BlockId, CellId, DropTarget, Page(..), Song, SongId, Toolbox, ToolboxId, TrackId)
import Riptide.Reducer as Reducer
import Riptide.Validation (valid)
import Riptide.View.Definitions as Definitions
import Riptide.View.Id (mintId)
import Riptide.View.Playhead as Playhead
import Riptide.View.Seed (seedApp)
import Riptide.View.Shell as Shell
import Riptide.View.Song as Song
import Web.Event.Event as Event
import Web.HTML.Event.DragEvent (DragEvent)
import Web.HTML.Event.DragEvent as DragEvent

data Action
  = Initialize
  | GoSong
  | GoDefs
  | ToggleEngine
  | Hush
  | NewSong
  | NewToolbox
  | OpenSong SongId
  | OpenToolbox ToolboxId
  | RenameSong SongId String
  | RenameToolbox ToolboxId String
  | DuplicateSong SongId
  | DuplicateToolbox ToolboxId
  | DeleteSong SongId
  | DeleteToolbox ToolboxId
  | AddBlock
  | RenameBlock BlockId String
  | EditBlockCode BlockId String
  | ApplyBlock BlockId
  | ApplyAll
  | DeleteBlock BlockId
  | RenameTrack TrackId String
  | SetCtrl TrackId ControlKey String
  | StopTrack TrackId
  | AddTrack
  | DeleteTrack TrackId
  | AddCell TrackId
  | SelectCell TrackId CellId
  | ToggleCell TrackId CellId
  | EditCode TrackId CellId String
  | DeleteCell TrackId CellId
  | StartEdit String String
  | StopEdit
  | FocusCell CellId
  | BlurCell CellId
  | StartPaint TrackId Int
  | PaintEnter TrackId Int
  | StopPaint
  | StartTrackDrag TrackId
  | StartCellDrag TrackId CellId
  | DragOver DropTarget DragEvent
  | DropOn DropTarget DragEvent
  | EndDrag
  | TogglePlay
  | ToggleLoop
  | SetLoopStart String
  | SetLoopEnd String
  | MoveLoop Int
  | PlayheadTick H.SubscriptionId Number

component :: forall query input output m. MonadAff m => H.Component query input output m
component =
  H.mkComponent
    { initialState: const seedApp
    , render
    , eval: H.mkEval H.defaultEval { handleAction = handleAction, initialize = Just Initialize }
    }

render :: forall slots m. App -> H.ComponentHTML Action slots m
render app =
  Shell.render shellActions app
    case app.page of
      SongPage -> Song.render songActions app
      DefsPage -> Definitions.render definitionsActions app

shellActions :: Shell.ShellActions Action
shellActions =
  { goSong: GoSong
  , goDefs: GoDefs
  , toggleEngine: ToggleEngine
  , hush: Hush
  , newSong: NewSong
  , newToolbox: NewToolbox
  }

songActions :: Song.SongActions Action
songActions =
  { newSong: NewSong
  , openSong: OpenSong
  , renameSong: RenameSong
  , duplicateSong: DuplicateSong
  , deleteSong: DeleteSong
  , renameTrack: RenameTrack
  , setCtrl: SetCtrl
  , stopTrack: StopTrack
  , addTrack: AddTrack
  , deleteTrack: DeleteTrack
  , addCell: AddCell
  , selectCell: SelectCell
  , toggleCell: ToggleCell
  , editCode: EditCode
  , deleteCell: DeleteCell
  , startEdit: StartEdit
  , stopEdit: StopEdit
  , focusCell: FocusCell
  , blurCell: BlurCell
  , startPaint: StartPaint
  , paintEnter: PaintEnter
  , stopPaint: StopPaint
  , startTrackDrag: StartTrackDrag
  , startCellDrag: StartCellDrag
  , dragOver: DragOver
  , dropOn: DropOn
  , endDrag: EndDrag
  , togglePlay: TogglePlay
  , toggleLoop: ToggleLoop
  , setLoopStart: SetLoopStart
  , setLoopEnd: SetLoopEnd
  , moveLoop: MoveLoop
  }

definitionsActions :: Definitions.DefinitionsActions Action
definitionsActions =
  { newToolbox: NewToolbox
  , openToolbox: OpenToolbox
  , renameToolbox: RenameToolbox
  , duplicateToolbox: DuplicateToolbox
  , deleteToolbox: DeleteToolbox
  , addBlock: AddBlock
  , renameBlock: RenameBlock
  , editBlockCode: EditBlockCode
  , applyBlock: ApplyBlock
  , applyAll: ApplyAll
  , deleteBlock: DeleteBlock
  , startEdit: StartEdit
  , stopEdit: StopEdit
  }

handleAction :: forall output m. MonadAff m => Action -> H.HalogenM App Action () output m Unit
handleAction = case _ of
  Initialize -> do
    app <- H.get
    when app.playing startPlayhead
  GoSong ->
    H.modify_ \app ->
      case app.currentSongId of
        Just songId -> Reducer.openSong songId app
        Nothing -> app { page = SongPage }
  GoDefs ->
    H.modify_ \app ->
      case app.currentToolboxId of
        Just toolboxId -> Reducer.openToolbox toolboxId app
        Nothing -> app { page = DefsPage }
  ToggleEngine ->
    H.modify_ Reducer.toggleEngine
  Hush ->
    H.modify_ Reducer.hush
  NewSong -> do
    songId <- H.liftEffect (mintId "s")
    H.modify_ (Reducer.newSong songId)
  NewToolbox -> do
    toolboxId <- H.liftEffect (mintId "tb")
    H.modify_ (Reducer.newToolbox toolboxId)
  OpenSong songId ->
    H.modify_ (Reducer.openSong songId)
  OpenToolbox toolboxId ->
    H.modify_ (Reducer.openToolbox toolboxId)
  RenameSong songId name ->
    H.modify_ (Reducer.renameSong songId name)
  RenameToolbox toolboxId name ->
    H.modify_ (Reducer.renameToolbox toolboxId name)
  DuplicateSong songId -> do
    app <- H.get
    case songById songId app of
      Just source -> do
        newSongId <- H.liftEffect (mintId "s")
        trackIds <- traverse (const (H.liftEffect (mintId "t"))) source.tracks
        cellIds <- traverse (const (H.liftEffect (mintId "c"))) (Array.concatMap _.cells source.tracks)
        H.modify_ (Reducer.duplicateSong songId { songId: newSongId, trackIds, cellIds })
      Nothing ->
        pure unit
  DuplicateToolbox toolboxId -> do
    app <- H.get
    case toolboxById toolboxId app of
      Just source -> do
        newToolboxId <- H.liftEffect (mintId "tb")
        blockIds <- traverse (const (H.liftEffect (mintId "b"))) source.blocks
        H.modify_ (Reducer.duplicateToolbox toolboxId { toolboxId: newToolboxId, blockIds })
      Nothing ->
        pure unit
  DeleteSong songId ->
    H.modify_ (Reducer.deleteSong songId)
  DeleteToolbox toolboxId ->
    H.modify_ (Reducer.deleteToolbox toolboxId)
  AddBlock -> do
    blockId <- H.liftEffect (mintId "b")
    H.modify_ (Reducer.addBlock blockId)
  RenameBlock blockId name ->
    H.modify_ (Reducer.renameBlock blockId name)
  EditBlockCode blockId code ->
    H.modify_ (Reducer.editBlockCode blockId code)
  ApplyBlock blockId ->
    H.modify_ (Reducer.applyBlock blockId)
  ApplyAll ->
    H.modify_ Reducer.applyAll
  DeleteBlock blockId ->
    H.modify_ (Reducer.deleteBlock blockId)
  RenameTrack trackId name ->
    H.modify_ (Reducer.renameTrack trackId name)
  SetCtrl trackId key raw ->
    case Int.fromString raw of
      Just value -> H.modify_ (Reducer.setCtrl trackId key value)
      Nothing -> pure unit
  StopTrack trackId ->
    H.modify_ (Reducer.stopTrack trackId)
  AddTrack -> do
    trackId <- H.liftEffect (mintId "t")
    H.modify_ (Reducer.addTrack trackId)
  DeleteTrack trackId ->
    H.modify_ (Reducer.removeTrack trackId)
  AddCell trackId -> do
    cellId <- H.liftEffect (mintId "c")
    H.modify_ (Reducer.addCell trackId cellId)
  SelectCell trackId cellId ->
    H.modify_ (Reducer.selectCell trackId cellId)
  ToggleCell trackId cellId -> do
    app <- H.get
    if app.engine && cellIsLaunchable trackId cellId app then
      H.modify_ (Reducer.toggleCell trackId cellId)
    else
      pure unit
  EditCode trackId cellId code ->
    H.modify_ (Reducer.editCode trackId cellId code)
  DeleteCell trackId cellId ->
    H.modify_ (Reducer.removeCell trackId cellId)
  StartEdit kind id ->
    H.modify_ (Reducer.startEdit kind id)
  StopEdit ->
    H.modify_ Reducer.stopEdit
  FocusCell cellId ->
    H.modify_ \app -> app { focusCell = Just cellId }
  BlurCell cellId ->
    H.modify_ \app ->
      if app.focusCell == Just cellId then app { focusCell = Nothing } else app
  StartPaint trackId bar ->
    H.modify_ (Reducer.startPaint trackId bar)
  PaintEnter trackId bar ->
    H.modify_ (Reducer.paintEnter trackId bar)
  StopPaint ->
    H.modify_ Reducer.stopPaint
  StartTrackDrag trackId ->
    H.modify_ \app ->
      app
        { drag = Just { kind: "track", trackId, cellId: Nothing }
        , over = Nothing
        , confirm = Nothing
        }
  StartCellDrag trackId cellId ->
    H.modify_ \app ->
      app
        { drag = Just { kind: "cell", trackId, cellId: Just cellId }
        , over = Nothing
        , confirm = Nothing
        }
  DragOver target event -> do
    H.liftEffect (Event.preventDefault (DragEvent.toEvent event))
    H.liftEffect (Event.stopPropagation (DragEvent.toEvent event))
    H.modify_ \app ->
      if acceptsDrop target app then app { over = Just target } else app { over = Nothing }
  DropOn target event -> do
    H.liftEffect (Event.preventDefault (DragEvent.toEvent event))
    H.liftEffect (Event.stopPropagation (DragEvent.toEvent event))
    H.modify_ (clearDrag <<< applyDrop target)
  EndDrag ->
    H.modify_ clearDrag
  TogglePlay -> do
    H.modify_ Reducer.togglePlay
    app <- H.get
    when app.playing startPlayhead
  ToggleLoop ->
    H.modify_ Reducer.toggleLoop
  SetLoopStart raw ->
    case Int.fromString raw of
      Just value -> H.modify_ (Reducer.setLoopStart value)
      Nothing -> pure unit
  SetLoopEnd raw ->
    case Int.fromString raw of
      Just value -> H.modify_ (Reducer.setLoopEnd value)
      Nothing -> pure unit
  MoveLoop delta ->
    H.modify_ (Reducer.moveLoop delta)
  PlayheadTick subscriptionId dt -> do
    app <- H.get
    if app.playing then
      H.modify_ (advancePlayhead dt)
    else
      H.unsubscribe subscriptionId

startPlayhead :: forall output m. MonadAff m => H.HalogenM App Action () output m Unit
startPlayhead =
  H.subscribe' \subscriptionId ->
    Playhead.animationFrameEmitter (PlayheadTick subscriptionId)

advancePlayhead :: Number -> App -> App
advancePlayhead dt app =
  let
    result =
      Playhead.step
        { playhead: app.playhead
        , dtSeconds: dt
        , loopOn: app.loopOn
        , loopStart: app.loopStart
        , loopEnd: app.loopEnd
        , lastBar: Int.floor app.playhead
        }
    moved = app { playhead = result.playhead }
  in
    case result.changedBar of
      Just bar -> Reducer.applyAutomation bar moved
      Nothing -> moved

songById :: SongId -> App -> Maybe Song
songById songId app =
  Array.find (_.id >>> (_ == songId)) app.songs

toolboxById :: ToolboxId -> App -> Maybe Toolbox
toolboxById toolboxId app =
  Array.find (_.id >>> (_ == toolboxId)) app.toolboxes

cellIsLaunchable :: TrackId -> CellId -> App -> Boolean
cellIsLaunchable trackId cellId app =
  case app.currentSongId >>= \songId -> songById songId app of
    Just song ->
      case Array.find (_.id >>> (_ == trackId)) song.tracks of
        Just track ->
          case Array.find (_.id >>> (_ == cellId)) track.cells of
            Just cell -> (valid cell.code).valid
            Nothing -> false
        Nothing -> false
    Nothing -> false

acceptsDrop :: DropTarget -> App -> Boolean
acceptsDrop target app =
  case app.drag of
    Just drag
      | drag.kind == "track" ->
          target.kind == "track" && drag.trackId /= target.trackId
      | drag.kind == "cell" ->
          target.kind == "cell" || target.kind == "cell-append"
    _ ->
      false

applyDrop :: DropTarget -> App -> App
applyDrop target app =
  if not (acceptsDrop target app) then
    app
  else
    case app.drag of
      Just drag
        | drag.kind == "track" && target.kind == "track" ->
            Reducer.moveTrack drag.trackId target.trackId app
        | drag.kind == "cell" ->
            case drag.cellId of
              Just cellId ->
                Reducer.moveCell drag.trackId cellId target.trackId target.cellId app
              Nothing ->
                app
      _ ->
        app

clearDrag :: App -> App
clearDrag app =
  app { drag = Nothing, over = Nothing }

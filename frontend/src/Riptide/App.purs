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
import Riptide.Model (App, CellId, Page(..), Song, SongId, TrackId)
import Riptide.Reducer as Reducer
import Riptide.Validation (valid)
import Riptide.View.Definitions as Definitions
import Riptide.View.Id (mintId)
import Riptide.View.Seed (seedApp)
import Riptide.View.Shell as Shell
import Riptide.View.Song as Song

data Action
  = GoSong
  | GoDefs
  | ToggleEngine
  | Hush
  | NewSong
  | NewToolbox
  | OpenSong SongId
  | RenameSong SongId String
  | DuplicateSong SongId
  | DeleteSong SongId
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

component :: forall query input output m. MonadAff m => H.Component query input output m
component =
  H.mkComponent
    { initialState: const seedApp
    , render
    , eval: H.mkEval H.defaultEval { handleAction = handleAction }
    }

render :: forall slots m. App -> H.ComponentHTML Action slots m
render app =
  Shell.render shellActions app
    case app.page of
      SongPage -> Song.render songActions app
      DefsPage -> Definitions.render app

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
  }

handleAction :: forall output m. MonadAff m => Action -> H.HalogenM App Action () output m Unit
handleAction = case _ of
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
  RenameSong songId name ->
    H.modify_ (Reducer.renameSong songId name)
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
  DeleteSong songId ->
    H.modify_ (Reducer.deleteSong songId)
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

songById :: SongId -> App -> Maybe Song
songById songId app =
  Array.find (_.id >>> (_ == songId)) app.songs

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

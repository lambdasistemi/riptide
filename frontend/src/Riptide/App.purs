module Riptide.App
  ( component
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Riptide.Model (App, Page(..))
import Riptide.Reducer as Reducer
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
      SongPage -> Song.render app
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

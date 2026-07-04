module Riptide.View.Shell
  ( ShellActions
  , render
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..), maybe)
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Riptide.Model (App, ConnectionState(..), Page(..), Song, Toolbox, connectionLabel)
import Riptide.Validation (authoritativeValidation)
import Riptide.View.Icons (Icon(..))
import Riptide.View.Icons as Icons

type ShellActions action =
  { goSong :: action
  , goDefs :: action
  , toggleEngine :: action
  , hush :: action
  , newSong :: action
  , newToolbox :: action
  , exportSong :: action
  , importSong :: action
  , exportToolbox :: action
  , importToolbox :: action
  }

render
  :: forall action slots m
   . ShellActions action
  -> App
  -> HH.ComponentHTML action slots m
  -> HH.ComponentHTML action slots m
render actions app child =
  HH.main [ HP.classes [ HH.ClassName "rt-shell" ] ]
    [ HH.header [ HP.classes [ HH.ClassName "rt-topbar" ] ]
        [ HH.div [ HP.classes [ HH.ClassName "rt-brand" ] ] [ HH.text "riptide" ]
        , HH.nav [ HP.classes [ HH.ClassName "rt-tabs" ] ]
            [ tabButton "Song" (app.page == SongPage) actions.goSong
            , tabButton "Definitions" (app.page == DefsPage) actions.goDefs
            ]
        , HH.div [ HP.classes [ HH.ClassName "rt-spacer" ] ] []
        , chipButton (scopeClasses app) (scopeLabel app) actions.goDefs
        , chipButton (engineClasses app) (connectionLabel app.connection) actions.toggleEngine
        , Icons.iconButtonWithClasses "Stop everything" Hush [ HH.ClassName "rt-hush" ] actions.hush
        , HH.div [ HP.classes [ HH.ClassName "rt-active" ] ] [ HH.text (activeLabel app) ]
        ]
    , HH.div [ HP.classes [ HH.ClassName "rt-actions" ] ]
        [ Icons.iconButton "New song" Add actions.newSong
        , Icons.iconButton "New toolbox" Add actions.newToolbox
        , HH.div [ HP.classes [ HH.ClassName "rt-action-group" ] ]
            [ Icons.iconButton "Export song" Download actions.exportSong
            , Icons.iconButton "Import song" Upload actions.importSong
            ]
        , HH.div [ HP.classes [ HH.ClassName "rt-action-group" ] ]
            [ Icons.iconButton "Export toolbox" Download actions.exportToolbox
            , Icons.iconButton "Import toolbox" Upload actions.importToolbox
            ]
        ]
    , case app.toast of
        Just message ->
          HH.div [ HP.classes [ HH.ClassName "rt-toast" ], HP.attr (HH.AttrName "role") "status" ] [ HH.text message ]
        Nothing ->
          HH.text ""
    , child
    ]

tabButton :: forall action slots m. String -> Boolean -> action -> HH.ComponentHTML action slots m
tabButton label selected action =
  HH.button
    [ HP.classes [ HH.ClassName "rt-tab", if selected then HH.ClassName "is-selected" else HH.ClassName "is-idle" ]
    , HE.onClick \_ -> action
    ]
    [ HH.text label ]

chipButton :: forall action slots m. Array HH.ClassName -> String -> action -> HH.ComponentHTML action slots m
chipButton classes label action =
  HH.button [ HP.classes classes, HE.onClick \_ -> action ]
    [ HH.span [ HP.classes [ HH.ClassName "rt-dot" ] ] []
    , HH.span_ [ HH.text label ]
    ]

scopeClasses :: App -> Array HH.ClassName
scopeClasses app =
  [ HH.ClassName "rt-chip", HH.ClassName "rt-scope", if scopeInvalid app then HH.ClassName "is-invalid" else HH.ClassName "is-valid" ]

engineClasses :: App -> Array HH.ClassName
engineClasses app =
  [ HH.ClassName "rt-chip", HH.ClassName "rt-engine", connectionClass app.connection ]

scopeLabel :: App -> String
scopeLabel app =
  maybe "scope: none" (\toolbox -> "scope: " <> toolbox.name) (currentToolbox app)

scopeInvalid :: App -> Boolean
scopeInvalid app =
  maybe false (\toolbox -> Array.any (\block -> block.code /= "" && not (authoritativeValidation app.backendValidation block.code).valid) toolbox.blocks) (currentToolbox app)

connectionClass :: ConnectionState -> HH.ClassName
connectionClass = case _ of
  Connected -> HH.ClassName "is-valid"
  Connecting -> HH.ClassName "is-pending"
  Disconnected -> HH.ClassName "is-invalid"
  ConnectionError _ -> HH.ClassName "is-invalid"

activeLabel :: App -> String
activeLabel app =
  let
    count = maybe 0 (Array.length <<< Array.filter (_.active >>> (_ /= Nothing)) <<< _.tracks) (currentSong app)
  in
    if count == 0 then "idle" else show count <> " playing"

currentSong :: App -> Maybe Song
currentSong app =
  case app.currentSongId of
    Just songId -> Array.find (_.id >>> (_ == songId)) app.songs
    Nothing -> Nothing

currentToolbox :: App -> Maybe Toolbox
currentToolbox app =
  case app.currentToolboxId of
    Just toolboxId -> Array.find (_.id >>> (_ == toolboxId)) app.toolboxes
    Nothing -> Nothing

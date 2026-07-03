module Riptide.View.Definitions
  ( render
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Riptide.Helpers (cascade)
import Riptide.Model (App, Block, Toolbox)
import Riptide.Validation (valid)

render :: forall action slots m. App -> HH.ComponentHTML action slots m
render app =
  HH.section [ HP.classes [ HH.ClassName "rt-page", HH.ClassName "rt-defs" ] ]
    [ HH.div [ HP.classes [ HH.ClassName "rt-rail" ] ]
        [ HH.div [ HP.classes [ HH.ClassName "rt-rail-title" ] ] [ HH.text "Toolboxes" ]
        , HH.div_ (map toolboxRow app.toolboxes)
        ]
    , HH.div [ HP.classes [ HH.ClassName "rt-workspace" ] ]
        ( case currentToolbox app of
            Just toolbox -> toolboxShell app toolbox
            Nothing -> emptyShell
        )
    ]

toolboxRow :: forall action slots m. Toolbox -> HH.ComponentHTML action slots m
toolboxRow toolbox =
  HH.div [ HP.classes [ HH.ClassName "rt-list-row" ] ]
    [ HH.span_ [ HH.text toolbox.name ]
    , HH.small_ [ HH.text toolbox.id ]
    ]

toolboxShell :: forall action slots m. App -> Toolbox -> Array (HH.ComponentHTML action slots m)
toolboxShell app toolbox =
  [ HH.div [ HP.classes [ HH.ClassName "rt-page-header" ] ]
      [ HH.div_
          [ HH.h1_ [ HH.text toolbox.name ]
          , HH.p_ [ HH.text "Definitions placeholder" ]
          ]
      , HH.div [ HP.classes [ HH.ClassName "rt-count" ] ] [ HH.text (show (Array.length toolbox.blocks) <> " blocks") ]
      ]
  , HH.div [ HP.classes [ HH.ClassName "rt-block-grid" ] ] (map (blockCard app) toolbox.blocks)
  ]

blockCard :: forall action slots m. App -> Block -> HH.ComponentHTML action slots m
blockCard app block =
  let
    result = valid block.code
    impact = cascade app.songs block
    stateClass =
      if result.valid then HH.ClassName "is-valid" else HH.ClassName "is-invalid"
  in
    HH.article [ HP.classes [ HH.ClassName "rt-block", stateClass ] ]
      [ HH.div [ HP.classes [ HH.ClassName "rt-block-head" ] ]
          [ HH.h2_ [ HH.text block.name ]
          , HH.span_ [ HH.text (if result.valid then "valid" else "invalid") ]
          ]
      , HH.code_ [ HH.text block.code ]
      , HH.p_ [ HH.text (show impact.count <> " snippets in live scope") ]
      ]

emptyShell :: forall action slots m. Array (HH.ComponentHTML action slots m)
emptyShell =
  [ HH.div [ HP.classes [ HH.ClassName "rt-empty" ] ]
      [ HH.h1_ [ HH.text "No toolbox selected" ]
      , HH.p_ [ HH.text "Create or open a toolbox from the rail." ]
      ]
  ]

currentToolbox :: App -> Maybe Toolbox
currentToolbox app =
  case app.currentToolboxId of
    Just toolboxId -> Array.find (_.id >>> (_ == toolboxId)) app.toolboxes
    Nothing -> Nothing

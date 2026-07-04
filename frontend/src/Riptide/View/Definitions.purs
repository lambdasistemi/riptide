module Riptide.View.Definitions
  ( DefinitionsActions
  , render
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..), maybe)
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Riptide.Helpers (cascade)
import Riptide.Model (App, Block, BlockId, EditingTarget, Toolbox, ToolboxId)
import Riptide.Validation (ValidationResult, authoritativeValidation)

type DefinitionsActions action =
  { newToolbox :: action
  , openToolbox :: ToolboxId -> action
  , renameToolbox :: ToolboxId -> String -> action
  , duplicateToolbox :: ToolboxId -> action
  , deleteToolbox :: ToolboxId -> action
  , addBlock :: action
  , renameBlock :: BlockId -> String -> action
  , editBlockCode :: BlockId -> String -> action
  , applyBlock :: BlockId -> action
  , applyAll :: action
  , deleteBlock :: BlockId -> action
  , startEdit :: String -> String -> action
  , stopEdit :: action
  }

render :: forall action slots m. DefinitionsActions action -> App -> HH.ComponentHTML action slots m
render actions app =
  HH.section [ HP.classes [ HH.ClassName "rt-page", HH.ClassName "rt-defs" ] ]
    [ HH.div [ HP.classes [ HH.ClassName "rt-rail" ] ]
        [ HH.div [ HP.classes [ HH.ClassName "rt-rail-head" ] ]
            [ HH.div [ HP.classes [ HH.ClassName "rt-rail-title" ] ] [ HH.text "Toolboxes" ]
            , iconButton "New toolbox" "+" actions.newToolbox
            ]
        , HH.div [ HP.classes [ HH.ClassName "rt-rail-meta" ] ] [ HH.text (toolboxRailMeta app) ]
        , HH.div_ (map (toolboxRow actions app) app.toolboxes)
        ]
    , HH.div [ HP.classes [ HH.ClassName "rt-workspace" ] ]
        ( case currentToolbox app of
            Just toolbox -> toolboxShell actions app toolbox
            Nothing -> emptyShell
        )
    ]

toolboxRow :: forall action slots m. DefinitionsActions action -> App -> Toolbox -> HH.ComponentHTML action slots m
toolboxRow actions app toolbox =
  let
    selected = app.currentToolboxId == Just toolbox.id
    confirming = app.confirm == Just ("tbx:" <> toolbox.id)
    editing = isEditing "tbx" toolbox.id app.editing
  in
    HH.div
      [ HP.classes
          [ HH.ClassName "rt-list-row"
          , if selected then HH.ClassName "is-selected" else HH.ClassName "is-idle"
          ]
      ]
      [ HH.div [ HP.classes [ HH.ClassName "rt-list-main" ] ]
          [ if editing then
              HH.input
                [ HP.type_ HP.InputText
                , HP.value toolbox.name
                , HE.onValueInput (actions.renameToolbox toolbox.id)
                , HE.onBlur \_ -> actions.stopEdit
                ]
            else
              HH.button
                [ HP.type_ HP.ButtonButton
                , HP.classes [ HH.ClassName "rt-link-button" ]
                , HE.onClick \_ -> actions.openToolbox toolbox.id
                ]
                [ HH.text toolbox.name ]
          , HH.small_ [ HH.text (toolboxMeta app toolbox) ]
          ]
      , HH.div [ HP.classes [ HH.ClassName "rt-row-actions" ] ]
          [ iconButton "Open toolbox" "open" (actions.openToolbox toolbox.id)
          , iconButton "Rename toolbox" "rename" (actions.startEdit "tbx" toolbox.id)
          , iconButton "Duplicate toolbox" "copy" (actions.duplicateToolbox toolbox.id)
          , dangerButton (if confirming then "Confirm delete toolbox" else "Delete toolbox")
              (if confirming then "confirm" else "delete")
              (actions.deleteToolbox toolbox.id)
          ]
      ]

toolboxShell :: forall action slots m. DefinitionsActions action -> App -> Toolbox -> Array (HH.ComponentHTML action slots m)
toolboxShell actions app toolbox =
  [ HH.div [ HP.classes [ HH.ClassName "rt-page-header" ] ]
      [ HH.div_
          [ HH.div [ HP.classes [ HH.ClassName "rt-kicker" ] ] [ HH.text "Current toolbox" ]
          , HH.h1_ [ HH.text toolbox.name ]
          , HH.p_ [ HH.text "Edit shared pattern helpers, then apply valid changes to the live scope." ]
          ]
      , HH.div [ HP.classes [ HH.ClassName "rt-header-actions" ] ]
          [ HH.div [ HP.classes [ HH.ClassName "rt-count" ] ] [ HH.text (toolboxMeta app toolbox) ]
          , HH.button
              [ HP.type_ HP.ButtonButton
              , HE.onClick \_ -> actions.addBlock
              ]
              [ HH.text "Add block" ]
          , HH.button
              [ HP.type_ HP.ButtonButton
              , HP.disabled (not (canApplyAny app toolbox))
              , HE.onClick \_ -> actions.applyAll
              ]
              [ HH.text "Apply all" ]
          ]
      ]
  , if Array.null toolbox.blocks then
      HH.div [ HP.classes [ HH.ClassName "rt-empty" ] ]
        [ HH.h2_ [ HH.text "No definitions yet" ]
        , HH.p_ [ HH.text "Add a block to define reusable helpers for live snippets." ]
        ]
    else
      HH.div [ HP.classes [ HH.ClassName "rt-block-grid" ] ] (map (blockCard actions app) toolbox.blocks)
  ]

blockCard :: forall action slots m. DefinitionsActions action -> App -> Block -> HH.ComponentHTML action slots m
blockCard actions app block =
  let
    result = authoritativeValidation app.backendValidation block.code
    impact = cascade app.songs block
    unsaved = block.code /= block.applied
    canApply = result.valid && unsaved
    confirming = app.confirm == Just ("blk:" <> block.id)
  in
    HH.article [ HP.classes (blockClasses result unsaved) ]
      [ HH.div [ HP.classes [ HH.ClassName "rt-block-head" ] ]
          [ HH.input
              [ HP.type_ HP.InputText
              , HP.value block.name
              , HE.onValueInput (actions.renameBlock block.id)
              ]
          , HH.span [ HP.classes [ HH.ClassName "rt-block-state" ] ] [ HH.text (blockStateLabel result) ]
          ]
      , HH.textarea
          [ HP.value block.code
          , HP.rows 5
          , HP.placeholder "name = pattern transform"
          , HE.onValueInput (actions.editBlockCode block.id)
          ]
      , HH.div [ HP.classes [ HH.ClassName "rt-block-badges" ] ]
          [ HH.span [ HP.classes [ HH.ClassName "rt-badge" ] ] [ HH.text (if unsaved then "unsaved" else "applied") ]
          , HH.span [ HP.classes [ HH.ClassName "rt-badge" ] ] [ HH.text (show impact.count <> " live uses") ]
          ]
      , HH.div [ HP.classes [ HH.ClassName "rt-block-actions" ] ]
          [ HH.button
              [ HP.type_ HP.ButtonButton
              , HP.disabled (not canApply)
              , HE.onClick \_ -> actions.applyBlock block.id
              ]
              [ HH.text "Apply" ]
          , dangerButton (if confirming then "Confirm delete block" else "Delete block")
              (if confirming then "confirm" else "delete")
              (actions.deleteBlock block.id)
          ]
      , case result.error of
          Just err ->
            HH.div [ HP.classes [ HH.ClassName "rt-block-error" ] ] [ HH.text err ]
          Nothing ->
            HH.text ""
      , if not result.empty && not result.valid then
          cascadeWarning impact.count impact.list
        else
          HH.text ""
      ]

emptyShell :: forall action slots m. Array (HH.ComponentHTML action slots m)
emptyShell =
  [ HH.div [ HP.classes [ HH.ClassName "rt-empty" ] ]
      [ HH.h1_ [ HH.text "No toolbox selected" ]
      , HH.p_ [ HH.text "Create or open a toolbox from the rail." ]
      ]
  ]

cascadeWarning :: forall action slots m. Int -> Array { loc :: String, code :: String } -> HH.ComponentHTML action slots m
cascadeWarning count entries =
  HH.div [ HP.classes [ HH.ClassName "rt-cascade-warning" ] ]
    [ HH.div_ [ HH.text (show count <> " live snippets may be affected") ]
    , HH.ul_ (map cascadeEntry entries)
    ]

cascadeEntry :: forall action slots m. { loc :: String, code :: String } -> HH.ComponentHTML action slots m
cascadeEntry entry =
  HH.li_
    [ HH.strong_ [ HH.text entry.loc ]
    , HH.code_ [ HH.text entry.code ]
    ]

currentToolbox :: App -> Maybe Toolbox
currentToolbox app =
  case app.currentToolboxId of
    Just toolboxId -> Array.find (_.id >>> (_ == toolboxId)) app.toolboxes
    Nothing -> Nothing

toolboxRailMeta :: App -> String
toolboxRailMeta app =
  show (Array.length app.toolboxes) <> " defs" <> statusSuffix (Array.any (toolboxBroken app) app.toolboxes) (Array.any toolboxUnsaved app.toolboxes)

toolboxMeta :: App -> Toolbox -> String
toolboxMeta app toolbox =
  show (Array.length toolbox.blocks) <> " defs" <> statusSuffix (toolboxBroken app toolbox) (toolboxUnsaved toolbox)

statusSuffix :: Boolean -> Boolean -> String
statusSuffix broken unsaved =
  case { broken, unsaved } of
    { broken: true, unsaved: true } -> " · broken · unsaved"
    { broken: true, unsaved: false } -> " · broken"
    { broken: false, unsaved: true } -> " · unsaved"
    _ -> ""

toolboxBroken :: App -> Toolbox -> Boolean
toolboxBroken app toolbox =
  Array.any (\block -> not (authoritativeValidation app.backendValidation block.code).empty && not (authoritativeValidation app.backendValidation block.code).valid) toolbox.blocks

toolboxUnsaved :: Toolbox -> Boolean
toolboxUnsaved toolbox =
  Array.any (\block -> block.code /= block.applied) toolbox.blocks

canApplyAny :: App -> Toolbox -> Boolean
canApplyAny app toolbox =
  Array.any (\block -> (authoritativeValidation app.backendValidation block.code).valid && block.code /= block.applied) toolbox.blocks

blockClasses :: ValidationResult -> Boolean -> Array HH.ClassName
blockClasses result unsaved =
  [ HH.ClassName "rt-block"
  , if result.empty then HH.ClassName "is-empty" else if result.valid then HH.ClassName "is-valid" else HH.ClassName "is-invalid"
  , if unsaved then HH.ClassName "is-unsaved" else HH.ClassName "is-applied"
  ]

blockStateLabel :: ValidationResult -> String
blockStateLabel result
  | result.empty = "empty"
  | result.valid = "valid"
  | otherwise = "invalid"

iconButton :: forall action slots m. String -> String -> action -> HH.ComponentHTML action slots m
iconButton title label action =
  HH.button
    [ HP.type_ HP.ButtonButton
    , HP.title title
    , HE.onClick \_ -> action
    ]
    [ HH.text label ]

dangerButton :: forall action slots m. String -> String -> action -> HH.ComponentHTML action slots m
dangerButton title label action =
  HH.button
    [ HP.type_ HP.ButtonButton
    , HP.title title
    , HP.classes [ HH.ClassName "rt-danger" ]
    , HE.onClick \_ -> action
    ]
    [ HH.text label ]

isEditing :: String -> String -> Maybe EditingTarget -> Boolean
isEditing kind id =
  maybe false \target -> target.kind == kind && target.id == id

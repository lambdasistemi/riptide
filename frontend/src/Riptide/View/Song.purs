module Riptide.View.Song
  ( SongActions
  , render
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..), maybe)
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Riptide.Action (ControlKey(..))
import Riptide.Model (App, Cell, CellId, DropTarget, EditingTarget, Song, SongId, Track, TrackId)
import Riptide.Validation (ValidationResult, authoritativeValidation)
import Riptide.View.Score as Score
import Web.HTML.Event.DragEvent (DragEvent)

type SongActions action =
  { newSong :: action
  , openSong :: SongId -> action
  , renameSong :: SongId -> String -> action
  , duplicateSong :: SongId -> action
  , deleteSong :: SongId -> action
  , renameTrack :: TrackId -> String -> action
  , setCtrl :: TrackId -> ControlKey -> String -> action
  , stopTrack :: TrackId -> action
  , addTrack :: action
  , deleteTrack :: TrackId -> action
  , addCell :: TrackId -> action
  , selectCell :: TrackId -> CellId -> action
  , toggleCell :: TrackId -> CellId -> action
  , editCode :: TrackId -> CellId -> String -> action
  , deleteCell :: TrackId -> CellId -> action
  , startEdit :: String -> String -> action
  , stopEdit :: action
  , focusCell :: CellId -> action
  , blurCell :: CellId -> action
  , startPaint :: TrackId -> Int -> action
  , paintEnter :: TrackId -> Int -> action
  , stopPaint :: action
  , startTrackDrag :: TrackId -> action
  , startCellDrag :: TrackId -> CellId -> action
  , dragOver :: DropTarget -> DragEvent -> action
  , dropOn :: DropTarget -> DragEvent -> action
  , endDrag :: action
  , togglePlay :: action
  , toggleLoop :: action
  , setLoopStart :: String -> action
  , setLoopEnd :: String -> action
  , moveLoop :: Int -> action
  }

render :: forall action slots m. SongActions action -> App -> HH.ComponentHTML action slots m
render actions app =
  HH.section [ HP.classes [ HH.ClassName "rt-page", HH.ClassName "rt-song" ] ]
    [ HH.div [ HP.classes [ HH.ClassName "rt-rail" ] ]
        [ HH.div [ HP.classes [ HH.ClassName "rt-rail-head" ] ]
            [ HH.div [ HP.classes [ HH.ClassName "rt-rail-title" ] ] [ HH.text "Songs" ]
            , iconButton "New song" "+" actions.newSong
            ]
        , HH.div_ (map (songRow actions app) app.songs)
        ]
    , HH.div [ HP.classes [ HH.ClassName "rt-workspace" ] ]
        ( case currentSong app of
            Just song -> songShell actions app song
            Nothing -> emptyShell
        )
    ]

songRow :: forall action slots m. SongActions action -> App -> Song -> HH.ComponentHTML action slots m
songRow actions app song =
  let
    selected = app.currentSongId == Just song.id
    confirming = app.confirm == Just ("song:" <> song.id)
    editing = isEditing "song" song.id app.editing
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
                , HP.value song.name
                , HE.onValueInput (actions.renameSong song.id)
                , HE.onBlur \_ -> actions.stopEdit
                ]
            else
              HH.button
                [ HP.type_ HP.ButtonButton
                , HP.classes [ HH.ClassName "rt-link-button" ]
                , HE.onClick \_ -> actions.openSong song.id
                ]
                [ HH.text song.name ]
          , HH.small_ [ HH.text (show (Array.length song.tracks) <> " tracks") ]
          ]
      , HH.div [ HP.classes [ HH.ClassName "rt-row-actions" ] ]
          [ iconButton "Open song" "open" (actions.openSong song.id)
          , iconButton "Rename song" "rename" (actions.startEdit "song" song.id)
          , iconButton "Duplicate song" "copy" (actions.duplicateSong song.id)
          , dangerButton (if confirming then "Confirm delete song" else "Delete song")
              (if confirming then "confirm" else "delete")
              (actions.deleteSong song.id)
          ]
      ]

songShell :: forall action slots m. SongActions action -> App -> Song -> Array (HH.ComponentHTML action slots m)
songShell actions app song =
  [ HH.div [ HP.classes [ HH.ClassName "rt-page-header" ] ]
      [ HH.div_
          [ HH.div [ HP.classes [ HH.ClassName "rt-kicker" ] ] [ HH.text "Current song" ]
          , HH.h1_ [ HH.text song.name ]
          ]
      , HH.div [ HP.classes [ HH.ClassName "rt-header-actions" ] ]
          [ HH.div [ HP.classes [ HH.ClassName "rt-count" ] ] [ HH.text (show (Array.length song.tracks) <> " tracks") ]
          , HH.button
              [ HP.type_ HP.ButtonButton
              , HE.onClick \_ -> actions.addTrack
              ]
              [ HH.text "Add track" ]
          ]
      ]
  , HH.div [ HP.classes [ HH.ClassName "rt-launch-grid" ] ] (map (trackRow actions app) song.tracks)
  , Score.render (scoreActions actions) app song
  ]

scoreActions :: forall action. SongActions action -> Score.ScoreActions action
scoreActions actions =
  { startPaint: actions.startPaint
  , paintEnter: actions.paintEnter
  , stopPaint: actions.stopPaint
  , togglePlay: actions.togglePlay
  , toggleLoop: actions.toggleLoop
  , setLoopStart: actions.setLoopStart
  , setLoopEnd: actions.setLoopEnd
  , moveLoop: actions.moveLoop
  }

trackRow :: forall action slots m. SongActions action -> App -> Track -> HH.ComponentHTML action slots m
trackRow actions app track =
  let
    confirming = app.confirm == Just ("trk:" <> track.id)
    target = trackTarget track.id
  in
    HH.article
      [ HP.classes (trackClasses app target)
      , HP.style ("--track-hue: " <> show track.hue)
      , HE.onDragOver (actions.dragOver target)
      , HE.onDrop (actions.dropOn target)
      ]
      [ HH.div [ HP.classes [ HH.ClassName "rt-track-gutter" ] ]
          [ HH.button
              [ HP.type_ HP.ButtonButton
              , HP.title "Drag track"
              , HP.classes [ HH.ClassName "rt-drag-handle", HH.ClassName "rt-track-grip" ]
              , HP.draggable true
              , HE.onDragStart \_ -> actions.startTrackDrag track.id
              , HE.onDragEnd \_ -> actions.endDrag
              ]
              [ HH.text "grip" ]
          , HH.input
              [ HP.type_ HP.InputText
              , HP.value track.name
              , HE.onValueInput (actions.renameTrack track.id)
              ]
          , HH.div [ HP.classes [ HH.ClassName "rt-track-tools" ] ]
              [ HH.button
                  [ HP.type_ HP.ButtonButton
                  , HE.onClick \_ -> actions.stopTrack track.id
                  ]
                  [ HH.text "Stop" ]
              , dangerButton (if confirming then "Confirm delete track" else "Delete track")
                  (if confirming then "confirm" else "delete")
                  (actions.deleteTrack track.id)
              ]
          , HH.div [ HP.classes [ HH.ClassName "rt-ctrls" ] ]
              [ ctrlSlider actions track Vol "Vol" track.vol
              , ctrlSlider actions track Flt "Flt" track.flt
              , ctrlSlider actions track Dly "Dly" track.dly
              ]
          ]
      , HH.div [ HP.classes [ HH.ClassName "rt-cell-strip" ] ]
          (map (cellTile actions app track) track.cells <> [ addCellTile actions app track.id ])
      ]

ctrlSlider :: forall action slots m. SongActions action -> Track -> ControlKey -> String -> Int -> HH.ComponentHTML action slots m
ctrlSlider actions track key label value =
  HH.label [ HP.classes [ HH.ClassName "rt-ctrl" ] ]
    [ HH.span_ [ HH.text label ]
    , HH.input
        [ HP.type_ HP.InputRange
        , HP.min 0.0
        , HP.max 100.0
        , HP.step (HP.Step 1.0)
        , HP.value (show value)
        , HE.onValueInput (actions.setCtrl track.id key)
        ]
    , HH.output_ [ HH.text (show value) ]
    ]

cellTile :: forall action slots m. SongActions action -> App -> Track -> Cell -> HH.ComponentHTML action slots m
cellTile actions app track cell =
  let
    result = authoritativeValidation app.backendValidation cell.code
    active = track.active == Just cell.id
    selected = track.selected == Just cell.id
    editing = isEditing "cell" cell.id app.editing || app.focusCell == Just cell.id
    canLaunch = app.engine && result.valid
    confirming = app.confirm == Just ("cell:" <> cell.id)
    target = cellTarget track.id cell.id
  in
    HH.div
      [ HP.classes (cellClasses app target result active selected editing)
      , HE.onDragOver (actions.dragOver target)
      , HE.onDrop (actions.dropOn target)
      ]
      [ HH.div [ HP.classes [ HH.ClassName "rt-cell-head" ] ]
          [ HH.button
              [ HP.type_ HP.ButtonButton
              , HP.title "Drag cell"
              , HP.classes [ HH.ClassName "rt-drag-handle", HH.ClassName "rt-cell-grip" ]
              , HP.draggable true
              , HE.onDragStart \_ -> actions.startCellDrag track.id cell.id
              , HE.onDragEnd \_ -> actions.endDrag
              ]
              [ HH.text "grip" ]
          , HH.button
              [ HP.type_ HP.ButtonButton
              , HP.classes [ HH.ClassName "rt-cell-select" ]
              , HE.onClick \_ -> actions.selectCell track.id cell.id
              ]
              [ HH.text (if selected then "armed" else "select") ]
          , HH.span [ HP.classes [ HH.ClassName "rt-cell-state" ] ] [ HH.text (cellStateLabel result active selected editing) ]
          ]
      , HH.textarea
          [ HP.value cell.code
          , HP.rows 3
          , HP.placeholder "empty cell"
          , HE.onFocus \_ -> actions.focusCell cell.id
          , HE.onBlur \_ -> actions.blurCell cell.id
          , HE.onValueInput (actions.editCode track.id cell.id)
          ]
      , HH.div [ HP.classes [ HH.ClassName "rt-cell-actions" ] ]
          [ HH.button
              [ HP.type_ HP.ButtonButton
              , HP.disabled (not canLaunch)
              , HE.onClick \_ -> actions.toggleCell track.id cell.id
              ]
              [ HH.text (if active then "Stop" else "Launch") ]
          , dangerButton (if confirming then "Confirm delete cell" else "Delete cell")
              (if confirming then "confirm" else "delete")
              (actions.deleteCell track.id cell.id)
          ]
      , case result.error of
          Just err ->
            HH.div [ HP.classes [ HH.ClassName "rt-cell-error" ] ] [ HH.text err ]
          Nothing ->
            HH.text ""
      ]

addCellTile :: forall action slots m. SongActions action -> App -> TrackId -> HH.ComponentHTML action slots m
addCellTile actions app trackId =
  let
    target = appendTarget trackId
  in
  HH.button
    [ HP.type_ HP.ButtonButton
    , HP.classes
        [ HH.ClassName "rt-cell-add"
        , if overTarget target app.over then HH.ClassName "is-cell-append-drop" else HH.ClassName "is-not-cell-append-drop"
        ]
    , HE.onClick \_ -> actions.addCell trackId
    , HE.onDragOver (actions.dragOver target)
    , HE.onDrop (actions.dropOn target)
    ]
    [ HH.text "+ cell" ]

trackClasses :: App -> DropTarget -> Array HH.ClassName
trackClasses app target =
  [ HH.ClassName "rt-track"
  , if overTarget target app.over then HH.ClassName "is-track-drop-before" else HH.ClassName "is-not-track-drop"
  ]

cellClasses :: App -> DropTarget -> ValidationResult -> Boolean -> Boolean -> Boolean -> Array HH.ClassName
cellClasses app target result active selected editing =
  [ HH.ClassName "rt-cell"
  , if result.empty then HH.ClassName "is-empty" else HH.ClassName "has-text-idle"
  , if selected then HH.ClassName "is-selected-armed" else HH.ClassName "is-unselected"
  , if active then HH.ClassName "is-active-playing" else HH.ClassName "is-stopped"
  , if not result.empty && not result.valid then HH.ClassName "is-invalid" else HH.ClassName "is-valid"
  , if editing then HH.ClassName "is-being-edited" else HH.ClassName "is-not-editing"
  , if overTarget target app.over then HH.ClassName "is-cell-drop-before" else HH.ClassName "is-not-cell-drop"
  ]

trackTarget :: TrackId -> DropTarget
trackTarget trackId =
  { kind: "track", trackId, cellId: Nothing }

cellTarget :: TrackId -> CellId -> DropTarget
cellTarget trackId cellId =
  { kind: "cell", trackId, cellId: Just cellId }

appendTarget :: TrackId -> DropTarget
appendTarget trackId =
  { kind: "cell-append", trackId, cellId: Nothing }

overTarget :: DropTarget -> Maybe DropTarget -> Boolean
overTarget target =
  maybe false \over ->
    over.kind == target.kind && over.trackId == target.trackId && over.cellId == target.cellId

cellStateLabel :: ValidationResult -> Boolean -> Boolean -> Boolean -> String
cellStateLabel result active selected editing
  | editing = "editing"
  | active = "playing"
  | not result.empty && not result.valid = "invalid"
  | selected = "armed"
  | result.empty = "empty"
  | otherwise = "idle"

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

emptyShell :: forall action slots m. Array (HH.ComponentHTML action slots m)
emptyShell =
  [ HH.div [ HP.classes [ HH.ClassName "rt-empty" ] ]
      [ HH.h1_ [ HH.text "No song selected" ]
      , HH.p_ [ HH.text "Create or open a song from the rail." ]
      ]
  ]

currentSong :: App -> Maybe Song
currentSong app =
  case app.currentSongId of
    Just songId -> Array.find (_.id >>> (_ == songId)) app.songs
    Nothing -> Nothing

isEditing :: String -> String -> Maybe EditingTarget -> Boolean
isEditing kind id =
  maybe false \target -> target.kind == kind && target.id == id

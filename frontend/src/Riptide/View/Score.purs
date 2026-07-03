module Riptide.View.Score
  ( ScoreActions
  , render
  ) where

import Prelude

import Data.Array as Array
import Data.Int as Int
import Data.Maybe (Maybe(..), maybe)
import Data.String.CodeUnits as CodeUnits
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Riptide.Helpers (effectiveSelected, normalizeScore)
import Riptide.Model (App, Cell, Song, Track, TrackId, totalBars)

type ScoreActions action =
  { startPaint :: TrackId -> Int -> action
  , paintEnter :: TrackId -> Int -> action
  , stopPaint :: action
  , togglePlay :: action
  , toggleLoop :: action
  , setLoopStart :: String -> action
  , setLoopEnd :: String -> action
  , moveLoop :: Int -> action
  }

render :: forall action slots m. ScoreActions action -> App -> Song -> HH.ComponentHTML action slots m
render actions app song =
  let
    curBar = clampInt 0 (totalBars - 1) (Int.floor app.playhead)
    effLo = if app.loopOn then app.loopStart else 0
    effHi = if app.loopOn then app.loopEnd else totalBars
    emptySchedule = not (Array.any (Array.any identity <<< normalizeScore <<< _.score) song.tracks)
  in
    HH.section
      [ HP.classes [ HH.ClassName "rt-score" ]
      , HP.style ("--score-height: " <> show app.scoreHeight <> "px; --playhead-x: " <> show ((app.playhead / Int.toNumber totalBars) * 100.0) <> "%")
      , HE.onMouseUp \_ -> actions.stopPaint
      , HE.onMouseLeave \_ -> actions.stopPaint
      ]
      [ toolbar actions app curBar
      , HH.div [ HP.classes [ HH.ClassName "rt-score-mode" ] ]
          [ HH.label_
              [ HH.input [ HP.type_ HP.InputCheckbox ]
              , HH.span_ [ HH.text "Fixed playhead" ]
              ]
          ]
      , HH.div [ HP.classes [ HH.ClassName "rt-score-grid" ] ]
          (ruler effLo effHi curBar <> Array.concatMap (lane actions app effLo effHi curBar) song.tracks)
      , if Array.null song.tracks then
          HH.div [ HP.classes [ HH.ClassName "rt-score-empty" ] ] [ HH.text "Add a track to schedule the score." ]
        else if emptySchedule then
          HH.div [ HP.classes [ HH.ClassName "rt-score-empty" ] ] [ HH.text "Nothing scheduled yet. Paint bars to launch the selected variation." ]
        else
          HH.text ""
      ]

toolbar :: forall action slots m. ScoreActions action -> App -> Int -> HH.ComponentHTML action slots m
toolbar actions app curBar =
  HH.div [ HP.classes [ HH.ClassName "rt-score-toolbar" ] ]
    [ HH.div [ HP.classes [ HH.ClassName "rt-score-title" ] ]
        [ HH.div [ HP.classes [ HH.ClassName "rt-kicker" ] ] [ HH.text "Score" ]
        , HH.h2_ [ HH.text (if app.playing then "Timeline running" else "Timeline paused") ]
        ]
    , HH.div [ HP.classes [ HH.ClassName "rt-score-controls" ] ]
        [ HH.button
            [ HP.type_ HP.ButtonButton
            , HP.classes [ HH.ClassName "rt-score-play" ]
            , HE.onClick \_ -> actions.togglePlay
            ]
            [ HH.text (if app.playing then "Pause" else "Play") ]
        , HH.button
            [ HP.type_ HP.ButtonButton
            , HE.onClick \_ -> actions.toggleLoop
            ]
            [ HH.text (if app.loopOn then "Loop on" else "Loop off") ]
        , HH.span [ HP.classes [ HH.ClassName "rt-score-readout" ] ]
            [ HH.text
                ( "BAR " <> show (curBar + 1) <> " / "
                    <> if app.loopOn then "LOOP " <> show (app.loopStart + 1) <> "-" <> show app.loopEnd else "no loop"
                )
            ]
        ]
    , HH.div [ HP.classes [ HH.ClassName "rt-loop-controls" ] ]
        [ HH.button [ HP.type_ HP.ButtonButton, HE.onClick \_ -> actions.moveLoop (-1) ] [ HH.text "<" ]
        , numberField "Start" (app.loopStart + 1) (actions.setLoopStart <<< zeroBased)
        , numberField "End" app.loopEnd actions.setLoopEnd
        , HH.button [ HP.type_ HP.ButtonButton, HE.onClick \_ -> actions.moveLoop 1 ] [ HH.text ">" ]
        ]
    ]

numberField :: forall action slots m. String -> Int -> (String -> action) -> HH.ComponentHTML action slots m
numberField label value toAction =
  HH.label [ HP.classes [ HH.ClassName "rt-loop-field" ] ]
    [ HH.span_ [ HH.text label ]
    , HH.input
        [ HP.type_ HP.InputNumber
        , HP.min 1.0
        , HP.max (Int.toNumber totalBars)
        , HP.step (HP.Step 1.0)
        , HP.value (show value)
        , HE.onValueInput toAction
        ]
    ]

ruler :: forall action slots m. Int -> Int -> Int -> Array (HH.ComponentHTML action slots m)
ruler effLo effHi curBar =
  [ HH.div [ HP.classes [ HH.ClassName "rt-score-corner" ] ] [ HH.text "Tracks" ]
  , HH.div [ HP.classes [ HH.ClassName "rt-score-ruler" ] ]
      (Array.range 0 (totalBars - 1) <#> \bar ->
        HH.div
          [ HP.classes (barClasses effLo effHi curBar bar <> [ HH.ClassName "rt-ruler-cell" ]) ]
          [ HH.text (show (bar + 1)) ]
      )
  ]

lane :: forall action slots m. ScoreActions action -> App -> Int -> Int -> Int -> Track -> Array (HH.ComponentHTML action slots m)
lane actions app effLo effHi curBar track =
  let
    selected = effectiveSelected track
    playing = track.active /= Nothing
  in
    [ HH.div
        [ HP.classes [ HH.ClassName "rt-score-label" ]
        , HP.style ("--track-hue: " <> show track.hue)
        ]
        [ HH.span [ HP.classes [ HH.ClassName "rt-score-accent" ] ] []
        , HH.div [ HP.classes [ HH.ClassName "rt-score-label-main" ] ]
            [ HH.strong_ [ HH.text track.name ]
            , HH.small_ [ HH.text ("> " <> maybe "no cell selected" selectedCode selected) ]
            ]
        , HH.span
            [ HP.classes
                [ HH.ClassName "rt-score-on-dot"
                , if playing then HH.ClassName "is-on" else HH.ClassName "is-off"
                ]
            ]
            []
        ]
    , HH.div [ HP.classes [ HH.ClassName "rt-score-lane" ], HP.style ("--track-hue: " <> show track.hue) ]
        (Array.range 0 (totalBars - 1) <#> scoreCell actions app effLo effHi curBar track)
    ]

scoreCell :: forall action slots m. ScoreActions action -> App -> Int -> Int -> Int -> Track -> Int -> HH.ComponentHTML action slots m
scoreCell actions app effLo effHi curBar track bar =
  let
    painted = maybe false identity (Array.index (normalizeScore track.score) bar)
  in
    HH.button
      [ HP.type_ HP.ButtonButton
      , HP.classes
          ( barClasses effLo effHi curBar bar
              <> [ HH.ClassName "rt-score-cell"
                , if painted then HH.ClassName "is-painted" else HH.ClassName "is-blank"
                , if app.paint /= Nothing then HH.ClassName "is-painting" else HH.ClassName "is-ready"
                ]
          )
      , HE.onMouseDown \_ -> actions.startPaint track.id bar
      , HE.onMouseEnter \_ -> actions.paintEnter track.id bar
      ]
      [ HH.text "" ]

barClasses :: Int -> Int -> Int -> Int -> Array HH.ClassName
barClasses effLo effHi curBar bar =
  [ if bar == curBar then HH.ClassName "is-playhead" else HH.ClassName "is-not-playhead"
  , if bar < effLo || bar >= effHi then HH.ClassName "is-outside-loop" else HH.ClassName "is-inside-loop"
  ]

selectedCode :: Cell -> String
selectedCode cell =
  truncate 30 cell.code

truncate :: Int -> String -> String
truncate n value =
  if CodeUnits.length value <= n then value else CodeUnits.take n value <> "..."

zeroBased :: String -> String
zeroBased raw =
  case Int.fromString raw of
    Just n -> show (n - 1)
    Nothing -> raw

clampInt :: Int -> Int -> Int -> Int
clampInt lo hi value =
  max lo (min hi value)

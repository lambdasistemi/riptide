module Riptide.View.Icons
  ( Icon(..)
  , icon
  , iconButton
  , iconButtonDisabled
  , iconButtonWithClasses
  , cancelButton
  , dangerButton
  ) where

import Data.Array as Array
import Halogen.HTML as HH
import Halogen.HTML.Core (Namespace(..))
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Web.UIEvent.MouseEvent (MouseEvent)

data Icon
  = Add
  | ArrowLeft
  | ArrowRight
  | Cancel
  | Check
  | Copy
  | Delete
  | Download
  | Edit
  | Eye
  | Grip
  | Hush
  | Loop
  | Pause
  | Play
  | Stop
  | Upload

iconButton :: forall action slots m. String -> Icon -> action -> HH.ComponentHTML action slots m
iconButton title glyph action =
  iconButtonDisabled title glyph false action

iconButtonDisabled :: forall action slots m. String -> Icon -> Boolean -> action -> HH.ComponentHTML action slots m
iconButtonDisabled title glyph disabled action =
  button title glyph [ HH.ClassName "rt-icon-button" ] disabled action

iconButtonWithClasses :: forall action slots m. String -> Icon -> Array HH.ClassName -> action -> HH.ComponentHTML action slots m
iconButtonWithClasses title glyph classes action =
  button title glyph (Array.cons (HH.ClassName "rt-icon-button") classes) false action

cancelButton :: forall action slots m. String -> (MouseEvent -> action) -> HH.ComponentHTML action slots m
cancelButton title action =
  buttonWithClick title Cancel [ HH.ClassName "rt-icon-button", HH.ClassName "rt-cancel" ] false action

dangerButton :: forall action slots m. String -> Icon -> (MouseEvent -> action) -> HH.ComponentHTML action slots m
dangerButton title glyph action =
  buttonWithClick title glyph [ HH.ClassName "rt-icon-button", HH.ClassName "rt-danger" ] false action

button :: forall action slots m. String -> Icon -> Array HH.ClassName -> Boolean -> action -> HH.ComponentHTML action slots m
button title glyph classes disabled action =
  buttonWithClick title glyph classes disabled \_ -> action

buttonWithClick :: forall action slots m. String -> Icon -> Array HH.ClassName -> Boolean -> (MouseEvent -> action) -> HH.ComponentHTML action slots m
buttonWithClick title glyph classes disabled action =
  HH.button
    [ HP.type_ HP.ButtonButton
    , HP.title title
    , HP.attr (HH.AttrName "aria-label") title
    , HP.classes classes
    , HP.disabled disabled
    , HE.onClick action
    ]
    [ icon glyph ]

icon :: forall action slots m. Icon -> HH.ComponentHTML action slots m
icon glyph =
  svg case glyph of
    Add ->
      [ line "12" "5" "12" "19"
      , line "5" "12" "19" "12"
      ]
    ArrowLeft ->
      [ polyline "15 18 9 12 15 6" ]
    ArrowRight ->
      [ polyline "9 18 15 12 9 6" ]
    Cancel ->
      [ line "6" "6" "18" "18"
      , line "18" "6" "6" "18"
      ]
    Check ->
      [ polyline "5 13 9 17 19 7" ]
    Copy ->
      [ rect "8" "8" "11" "11"
      , path "M5 15H4a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h9a1 1 0 0 1 1 1v1"
      ]
    Delete ->
      [ path "M4 7h16"
      , path "M10 11v6"
      , path "M14 11v6"
      , path "M6 7l1 13h10l1-13"
      , path "M9 7V4h6v3"
      ]
    Download ->
      [ path "M12 4v10"
      , polyline "8 10 12 14 16 10"
      , path "M5 19h14"
      ]
    Edit ->
      [ path "M4 20h4l11-11a2.8 2.8 0 0 0-4-4L4 16v4Z"
      , path "M13.5 6.5l4 4"
      ]
    Eye ->
      [ path "M2 12s4-6 10-6 10 6 10 6-4 6-10 6S2 12 2 12Z"
      , circle "12" "12" "3"
      ]
    Grip ->
      [ circle "9" "6" "1.2"
      , circle "15" "6" "1.2"
      , circle "9" "12" "1.2"
      , circle "15" "12" "1.2"
      , circle "9" "18" "1.2"
      , circle "15" "18" "1.2"
      ]
    Hush ->
      [ path "M4 10v4h4l5 4V6l-5 4H4Z"
      , line "17" "9" "21" "15"
      , line "21" "9" "17" "15"
      ]
    Loop ->
      [ path "M17 2l4 4-4 4"
      , path "M3 11V9a3 3 0 0 1 3-3h15"
      , path "M7 22l-4-4 4-4"
      , path "M21 13v2a3 3 0 0 1-3 3H3"
      ]
    Pause ->
      [ line "9" "5" "9" "19"
      , line "15" "5" "15" "19"
      ]
    Play ->
      [ path "M8 5v14l11-7-11-7Z" ]
    Stop ->
      [ rect "7" "7" "10" "10" ]
    Upload ->
      [ path "M12 20V10"
      , polyline "8 14 12 10 16 14"
      , path "M5 5h14"
      ]

svg :: forall action slots m. Array (HH.ComponentHTML action slots m) -> HH.ComponentHTML action slots m
svg children =
  HH.elementNS svgNS (HH.ElemName "svg")
    [ HP.attr (HH.AttrName "viewBox") "0 0 24 24"
    , HP.attr (HH.AttrName "aria-hidden") "true"
    , HP.attr (HH.AttrName "focusable") "false"
    , HP.attr (HH.AttrName "class") "rt-icon"
    ]
    children

svgNS :: Namespace
svgNS =
  Namespace "http://www.w3.org/2000/svg"

path :: forall action slots m. String -> HH.ComponentHTML action slots m
path d =
  HH.elementNS svgNS (HH.ElemName "path")
    [ HP.attr (HH.AttrName "d") d ]
    []

line :: forall action slots m. String -> String -> String -> String -> HH.ComponentHTML action slots m
line x1 y1 x2 y2 =
  HH.elementNS svgNS (HH.ElemName "line")
    [ HP.attr (HH.AttrName "x1") x1
    , HP.attr (HH.AttrName "y1") y1
    , HP.attr (HH.AttrName "x2") x2
    , HP.attr (HH.AttrName "y2") y2
    ]
    []

polyline :: forall action slots m. String -> HH.ComponentHTML action slots m
polyline points =
  HH.elementNS svgNS (HH.ElemName "polyline")
    [ HP.attr (HH.AttrName "points") points ]
    []

rect :: forall action slots m. String -> String -> String -> String -> HH.ComponentHTML action slots m
rect x y width height =
  HH.elementNS svgNS (HH.ElemName "rect")
    [ HP.attr (HH.AttrName "x") x
    , HP.attr (HH.AttrName "y") y
    , HP.attr (HH.AttrName "width") width
    , HP.attr (HH.AttrName "height") height
    ]
    []

circle :: forall action slots m. String -> String -> String -> HH.ComponentHTML action slots m
circle cx cy r =
  HH.elementNS svgNS (HH.ElemName "circle")
    [ HP.attr (HH.AttrName "cx") cx
    , HP.attr (HH.AttrName "cy") cy
    , HP.attr (HH.AttrName "r") r
    ]
    []

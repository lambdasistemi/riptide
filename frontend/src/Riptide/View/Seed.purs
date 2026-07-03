module Riptide.View.Seed
  ( seedApp
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Riptide.Model (App, defaultApp)

seedApp :: App
seedApp =
  defaultApp
    { currentSongId = Just "sA"
    , currentToolboxId = Just "tb1"
    , songs =
        [ { id: "sA"
          , name: "midnight set"
          , tracks:
              [ { id: "t1", name: "drums", hue: 25, active: Just "c1", selected: Just "c1", vol: 92, flt: 100, dly: 0, score: mk [ 0, 1, 2, 3, 4, 5 ], cells: [ cell "c1" "s \"bd*4\"", cell "c2" "s \"bd*2 sn:3\"", cell "c3" "s \"bd(3,8)\" # gain 1.1" ] }
              , { id: "t2", name: "hats", hue: 95, active: Nothing, selected: Just "c4", vol: 74, flt: 88, dly: 12, score: mk [ 6, 7, 8, 9 ], cells: [ cell "c4" "s \"hh*8\" # feel", cell "c5" "s \"hh*16?\" # pan sine" ] }
              , { id: "t3", name: "melody", hue: 200, active: Just "c8", selected: Just "c8", vol: 80, flt: 72, dly: 30, score: mk [ 2, 3, 4, 5, 6, 7, 8 ], cells: [ cell "c6" "s \"arpy*4\" # feel", cell "c7" "n \"0 3 5 7\" # s \"arpy\" # feel", cell "c8" "n (run 8) # s \"arpy\" # room 0.3" ] }
              , { id: "t4", name: "bass", hue: 285, active: Nothing, selected: Just "c9", vol: 85, flt: 60, dly: 0, score: mk [ 8, 9, 10, 11 ], cells: [ cell "c9" "note \"c2 e2 g2\" # s \"bass\"", cell "c10" "s \"jvbass*2 # crush 4" ] }
              , { id: "t5", name: "texture", hue: 330, active: Nothing, selected: Just "c11", vol: 66, flt: 45, dly: 55, score: mk [ 0, 1, 12, 13, 14, 15 ], cells: [ cell "c11" "s \"pad\" # room 0.6 # size 0.9" ] }
              ]
          }
        , { id: "sB"
          , name: "warm-up"
          , tracks:
              [ { id: "tbA", name: "pulse", hue: 25, active: Just "ca1", selected: Just "ca1", vol: 70, flt: 82, dly: 0, score: mk [], cells: [ cell "ca1" "s \"bd*2\"", cell "ca2" "s \"bd ~ bd ~\"" ] }
              , { id: "tbB", name: "wash", hue: 200, active: Nothing, selected: Just "cb1", vol: 60, flt: 55, dly: 40, score: mk [], cells: [ cell "cb1" "s \"pad\" # feel", cell "cb2" "s \"pad:2\" # room 0.5" ] }
              ]
          }
        ]
    , toolboxes =
        [ { id: "tb1"
          , name: "live set"
          , blocks:
              [ block "b1" "bpm" "bpm = setcps (130/60/4)" "bpm = setcps (130/60/4)"
              , block "b2" "swing" "swing = (# nudge \"0 0.008 0 0.012\")" "swing = (# nudge \"0 0.008 0 0.012\")"
              , block "b3" "feel" "feel = (# room 0.4 # size 0.9" "feel = (# room 0.35 # size 0.8)"
              , block "b4" "stut2" "stut2 = stut 2 0.5 0.1" "stut2 = stut 2 0.5 0.1"
              ]
          }
        , { id: "tb2"
          , name: "ambient rig"
          , blocks:
              [ block "b5" "drift" "drift = slow 8 . (# gain 0.8)" "drift = slow 8 . (# gain 0.8)"
              , block "b6" "wash" "wash = (# room 0.9 # size 0.95 # orbit 1)" "wash = (# room 0.9 # size 0.95 # orbit 1)"
              ]
          }
        ]
    }

cell
  :: String
  -> String
  -> { id :: String
     , code :: String
     }
cell id code =
  { id, code }

block
  :: String
  -> String
  -> String
  -> String
  -> { id :: String
     , name :: String
     , code :: String
     , applied :: String
     }
block id name code applied =
  { id, name, code, applied }

mk :: Array Int -> Array Boolean
mk onBars =
  map (\bar -> Array.elem bar onBars)
    [ 0
    , 1
    , 2
    , 3
    , 4
    , 5
    , 6
    , 7
    , 8
    , 9
    , 10
    , 11
    , 12
    , 13
    , 14
    , 15
    ]

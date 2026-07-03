module Riptide.View.Song
  ( render
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Riptide.Model (App, Song, Track)

render :: forall action slots m. App -> HH.ComponentHTML action slots m
render app =
  HH.section [ HP.classes [ HH.ClassName "rt-page", HH.ClassName "rt-song" ] ]
    [ HH.div [ HP.classes [ HH.ClassName "rt-rail" ] ]
        [ HH.div [ HP.classes [ HH.ClassName "rt-rail-title" ] ] [ HH.text "Songs" ]
        , HH.div_ (map songRow app.songs)
        ]
    , HH.div [ HP.classes [ HH.ClassName "rt-workspace" ] ]
        ( case currentSong app of
            Just song -> songShell song
            Nothing -> emptyShell
        )
    ]

songRow :: forall action slots m. Song -> HH.ComponentHTML action slots m
songRow song =
  HH.div [ HP.classes [ HH.ClassName "rt-list-row" ] ]
    [ HH.span_ [ HH.text song.name ]
    , HH.small_ [ HH.text song.id ]
    ]

songShell :: forall action slots m. Song -> Array (HH.ComponentHTML action slots m)
songShell song =
  [ HH.div [ HP.classes [ HH.ClassName "rt-page-header" ] ]
      [ HH.div_
          [ HH.h1_ [ HH.text song.name ]
          , HH.p_ [ HH.text "Launch grid placeholder" ]
          ]
      , HH.div [ HP.classes [ HH.ClassName "rt-count" ] ] [ HH.text (show (Array.length song.tracks) <> " tracks") ]
      ]
  , HH.div [ HP.classes [ HH.ClassName "rt-track-stack" ] ] (map trackCard song.tracks)
  , HH.div [ HP.classes [ HH.ClassName "rt-score-placeholder" ] ]
      [ HH.h2_ [ HH.text "Score timeline" ]
      , HH.p_ [ HH.text "Placeholder for ticket #6" ]
      ]
  ]

trackCard :: forall action slots m. Track -> HH.ComponentHTML action slots m
trackCard track =
  HH.article [ HP.classes [ HH.ClassName "rt-track" ] ]
    [ HH.div_
        [ HH.h2_ [ HH.text track.name ]
        , HH.p_ [ HH.text (show (Array.length track.cells) <> " cells") ]
        ]
    , HH.div [ HP.classes [ HH.ClassName "rt-cell-strip" ] ] (map cellPill track.cells)
    ]

cellPill :: forall action slots m r. { code :: String | r } -> HH.ComponentHTML action slots m
cellPill cell =
  HH.code [ HP.classes [ HH.ClassName "rt-cell-pill" ] ] [ HH.text cell.code ]

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

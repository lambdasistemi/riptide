module Test.Main where

import Prelude

import Data.Array (length)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Aff (launchAff_)
import Riptide.Helpers (cascade, collectIds, definedNames, duplicateIds, effectiveSelected, normalizeScore)
import Riptide.Model (Cell, Song, Track, totalBars)
import Riptide.Validation (valid)
import Test.Spec (describe, it)
import Test.Spec.Assertions (shouldEqual)
import Test.Spec.Reporter.Console (consoleReporter)
import Test.Spec.Runner (runSpec)

main :: Effect Unit
main =
  launchAff_ $ runSpec [ consoleReporter ] do
    describe "validation" do
      it "distinguishes empty code from invalid code" do
        valid "   " `shouldEqual` { empty: true, valid: false, error: Nothing }
        valid "d1 $ sound \"bd" `shouldEqual`
          { empty: false, valid: false, error: Just "unbalanced quote" }

      it "checks bracket and parenthesis balance" do
        valid "d1 $ sound (\"bd\" # gain 1" `shouldEqual`
          { empty: false, valid: false, error: Just "missing )" }
        valid "d1 $ sound [\"bd\"" `shouldEqual`
          { empty: false, valid: false, error: Just "missing ]" }
        valid "d1 $ sound \"bd\"" `shouldEqual`
          { empty: false, valid: true, error: Nothing }

    describe "definition names" do
      it "parses optional let bindings only at line starts" do
        definedNames "feel = (# room 0.4)\n  let swing_2 = nudge 0.01\nx feel = ignored\n_kit = sound \"bd\"" `shouldEqual`
          [ "feel", "swing_2", "_kit" ]

    describe "cascade" do
      it "counts whole-word uses across every song and returns the first five locations" do
        let
          result =
            cascade sampleSongs
              { id: "b1"
              , name: "feel"
              , code: "feel = (# room 0.4)\nlet swing = nudge 0.01"
              , applied: "feel = (# room 0.35)"
              }

        result.names `shouldEqual` [ "feel", "swing" ]
        result.count `shouldEqual` 5
        length result.list `shouldEqual` 5
        result.list `shouldEqual`
          [ { loc: "midnight set › drums", code: "d1 $ sound \"bd\" # feel" }
          , { loc: "midnight set › drums", code: "d1 $ sound \"cp\" # swing" }
          , { loc: "midnight set › lead", code: "d1 $ sound \"arpy\" # feel" }
          , { loc: "warm-up › hats", code: "d1 $ sound \"hh\" # swing" }
          , { loc: "warm-up › hats", code: "d1 $ sound \"oh\" # feel # swing" }
          ]

    describe "selection and score helpers" do
      it "falls back from a stale selected id to the first cell" do
        effectiveSelected trackWithStaleSelection `shouldEqual`
          Just { id: "c1", code: "d1 $ sound \"bd\"" }

      it "returns no effective selection when the track has no cells" do
        effectiveSelected (trackWithStaleSelection { cells = [] }) `shouldEqual` Nothing

      it "normalizes scores to the fixed total bar count" do
        normalizeScore [ true, false ] `shouldEqual`
          [ true
          , false
          , false
          , false
          , false
          , false
          , false
          , false
          , false
          , false
          , false
          , false
          , false
          , false
          , false
          , false
          ]
        length (normalizeScore (map (const true) (normalizeScore [] <> normalizeScore []))) `shouldEqual` totalBars

    describe "id helpers" do
      it "collects ids and reports duplicates" do
        collectIds sampleSongs `shouldEqual`
          [ "s1", "t1", "c1", "c2", "t2", "c3", "s2", "t3", "c4", "c5", "c6" ]
        duplicateIds sampleSongs `shouldEqual` []
        duplicateIds (sampleSongs <> [ song "s1" "duplicate" [] ]) `shouldEqual` [ "s1" ]

sampleSongs :: Array Song
sampleSongs =
  [ song "s1" "midnight set"
      [ track "t1" "drums"
          [ cell "c1" "d1 $ sound \"bd\" # feel"
          , cell "c2" "d1 $ sound \"cp\" # swing"
          ]
      , track "t2" "lead"
          [ cell "c3" "d1 $ sound \"arpy\" # feel" ]
      ]
  , song "s2" "warm-up"
      [ track "t3" "hats"
          [ cell "c4" "d1 $ sound \"hh\" # swing"
          , cell "c5" "d1 $ sound \"oh\" # feel # swing"
          , cell "c6" "d1 $ sound \"feelings\""
          ]
      ]
  ]

trackWithStaleSelection :: Track
trackWithStaleSelection =
  ( track "t1" "drums"
      [ cell "c1" "d1 $ sound \"bd\""
      , cell "c2" "d1 $ sound \"cp\""
      ]
  )
    { selected = Just "missing" }

song :: String -> String -> Array Track -> Song
song id name tracks =
  { id, name, tracks }

track :: String -> String -> Array Cell -> Track
track id name cells =
  { id
  , name
  , hue: 200
  , vol: 80
  , flt: 100
  , dly: 0
  , active: Nothing
  , selected: Nothing
  , score: normalizeScore []
  , cells
  }

cell :: String -> String -> Cell
cell id code =
  { id, code }

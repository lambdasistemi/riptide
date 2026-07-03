module Test.Main where

import Prelude

import Data.Array (length)
import Data.Array as Array
import Data.Foldable (all)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Aff (launchAff_)
import Riptide.Action (ControlKey(..))
import Riptide.Helpers (cascade, collectIds, definedNames, duplicateIds, effectiveSelected, normalizeScore)
import Riptide.Model (Cell, Song, Track, totalBars)
import Riptide.Model as Model
import Riptide.ImportExport as ImportExport
import Riptide.Reducer as Reducer
import Riptide.Validation (valid)
import Test.Spec (describe, it)
import Test.Spec.Assertions (shouldEqual)
import Test.Spec.QuickCheck (quickCheck)
import Test.QuickCheck.Gen as Gen
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

    describe "reducers" do
      it "silences current tracks when the engine turns off" do
        let
          app = appWithSong
          off = Reducer.toggleEngine app

        off.engine `shouldEqual` false
        map _.active (currentTracks off) `shouldEqual` [ Nothing, Nothing, Nothing ]

      it "launches, selects, and clears invalid active code edits" do
        let
          launched = Reducer.toggleCell "t1" "c2" appWithSong
          broken = Reducer.editCode "t1" "c2" "d1 $ sound \"bd" launched

        (map _.selected (currentTracks launched)) `shouldEqual` [ Just "c2", Just "c3", Just "c4" ]
        (map _.active (currentTracks launched)) `shouldEqual` [ Just "c2", Just "c3", Just "missing" ]
        (map _.active (currentTracks broken)) `shouldEqual` [ Nothing, Just "c3", Just "missing" ]

      it "gates destructive track and cell deletes behind armDelete" do
        let
          armed = Reducer.removeCell "t1" "c2" appWithSong
          deleted = Reducer.removeCell "t1" "c2" armed
          deletedTrack = Reducer.removeTrack "t2" (Reducer.removeTrack "t2" deleted)

        map (_.id) (trackById "t1" armed).cells `shouldEqual` [ "c1", "c2" ]
        (trackById "t1" deleted).selected `shouldEqual` Nothing
        map (_.id) (trackById "t1" deleted).cells `shouldEqual` [ "c1" ]
        map (_.id) (currentTracks deletedTrack) `shouldEqual` [ "t1", "t3" ]

      it "adds tracks and cells with explicit ids and normalized scores" do
        let
          app = Reducer.addCell "t1" "c7" (Reducer.addTrack "t4" appWithSong)
          addedTrack = trackById "t4" app

        map (_.id) (trackById "t1" app).cells `shouldEqual` [ "c1", "c2", "c7" ]
        (Reducer.setCtrl "t4" Vol 42 app # trackById "t4").vol `shouldEqual` 42
        addedTrack.name `shouldEqual` "track 4"
        addedTrack.hue `shouldEqual` 285
        length addedTrack.score `shouldEqual` totalBars

      it "applies only valid toolbox blocks" do
        let
          once = Reducer.applyBlock "b1" appWithToolbox
          allApplied = Reducer.applyAll once

        map _.applied (currentBlocks once) `shouldEqual` [ "feel = (# room 0.4)", "" ]
        map _.applied (currentBlocks allApplied) `shouldEqual` [ "feel = (# room 0.4)", "" ]

    describe "automation and score helpers" do
      it "drives painted tracks, leaves unpainted tracks alone, and respects engine validity" do
        let
          bar0 = Reducer.applyAutomation 0 appWithSong
          engineOff = Reducer.applyAutomation 0 (appWithSong { engine = false })
          bar1 = Reducer.applyAutomation 1 appWithSong

        map _.active (currentTracks bar0) `shouldEqual` [ Just "c2", Just "c3", Nothing ]
        map _.active (currentTracks engineOff) `shouldEqual` [ Nothing, Just "c3", Nothing ]
        map _.active (currentTracks bar1) `shouldEqual` [ Nothing, Just "c3", Nothing ]

      it "paint gestures write the gesture value and stop cleanly" do
        let
          painted = Reducer.paintEnter "t1" 1 (Reducer.startPaint "t1" 0 appWithSong)
          stopped = Reducer.stopPaint painted

        Array.take 2 (trackById "t1" painted).score `shouldEqual` [ false, false ]
        stopped.paint `shouldEqual` Nothing

      it "clamps loop limit changes and snaps playhead into range" do
        let
          moved = Reducer.moveLoop 20 (appWithSong { loopStart = 4, loopEnd = 8, playhead = 2.0 })
          startMoved = Reducer.setLoopStart 12 (appWithSong { loopStart = 4, loopEnd = 8, playhead = 2.0 })
          endMoved = Reducer.setLoopEnd (-1) (appWithSong { loopStart = 4, loopEnd = 8, playhead = 12.0 })

        { start: moved.loopStart, end: moved.loopEnd, playhead: moved.playhead } `shouldEqual`
          { start: 12, end: 16, playhead: 12.0 }
        { start: startMoved.loopStart, end: startMoved.loopEnd, playhead: startMoved.playhead } `shouldEqual`
          { start: 7, end: 8, playhead: 7.0 }
        { start: endMoved.loopStart, end: endMoved.loopEnd, playhead: endMoved.playhead } `shouldEqual`
          { start: 4, end: 5, playhead: 4.999 }

    describe "song and toolbox transforms" do
      it "duplicates songs with regenerated ids and remapped active/selected cells" do
        let
          duplicated = Reducer.duplicateSong "s1"
            { songId: "s-copy", trackIds: [ "nt1", "nt2", "nt3" ], cellIds: [ "nc1", "nc2", "nc3", "nc4", "nc5" ] }
            appWithSong
          copy = currentSong duplicated

        copy.id `shouldEqual` "s-copy"
        copy.name `shouldEqual` "midnight set copy"
        map _.id copy.tracks `shouldEqual` [ "nt1", "nt2", "nt3" ]
        map (_.active) copy.tracks `shouldEqual` [ Just "nc1", Just "nc3", Nothing ]
        map (_.selected) copy.tracks `shouldEqual` [ Just "nc2", Just "nc3", Just "nc4" ]
        all (\track -> length track.score == totalBars) copy.tracks `shouldEqual` true

      it "exports songs and toolboxes to stable wire records" do
        ImportExport.exportSong sampleSong `shouldEqual`
          { riptideSong: 1
          , name: "midnight set"
          , tracks:
              [ { name: "drums"
                , hue: Just 25
                , vol: Just 80
                , flt: Just 100
                , dly: Just 0
                , active: Just "c1"
                , selected: Just "c2"
                , score: normalizeScore [ true, false ]
                , cells:
                    [ { id: "c1", code: "d1 $ sound \"bd\"" }
                    , { id: "c2", code: "d1 $ sound \"cp\"" }
                    ]
                }
              , { name: "lead"
                , hue: Just 95
                , vol: Just 80
                , flt: Just 100
                , dly: Just 0
                , active: Just "c3"
                , selected: Just "c3"
                , score: normalizeScore []
                , cells: [ { id: "c3", code: "d1 $ sound \"arpy\"" } ]
                }
              , { name: "bad"
                , hue: Just 200
                , vol: Just 80
                , flt: Just 100
                , dly: Just 0
                , active: Just "missing"
                , selected: Just "c4"
                , score: normalizeScore [ true ]
                , cells:
                    [ { id: "c4", code: "d1 $ sound \"bd" }
                    , { id: "c5", code: "d1 $ sound \"hh\"" }
                    ]
                }
              ]
          }
        ImportExport.exportToolbox (currentToolbox appWithToolbox) `shouldEqual`
          { riptideToolbox: 1
          , name: "live defs"
          , blocks:
              [ { name: "feel", code: "feel = (# room 0.4)" }
              , { name: "broken", code: "broken = (# room 0.4" }
              ]
          }

      it "imports songs with fresh ids, normalized scores, remapped references, and current page" do
        let
          imported = ImportExport.importSong "s-import" [ "it1" ] [ "ic1", "ic2" ] exportedSong appEmpty
          song' = currentSong imported

        imported.page `shouldEqual` Model.SongPage
        imported.toast `shouldEqual` Just "Imported song imported set"
        song'.id `shouldEqual` "s-import"
        map _.id song'.tracks `shouldEqual` [ "it1" ]
        map _.id (trackById "it1" imported).cells `shouldEqual` [ "ic1", "ic2" ]
        (trackById "it1" imported).active `shouldEqual` Just "ic2"
        (trackById "it1" imported).selected `shouldEqual` Just "ic1"
        length (trackById "it1" imported).score `shouldEqual` totalBars

      it "imports toolboxes with fresh ids and only applies valid block code" do
        let
          imported = ImportExport.importToolbox "tbx-import" [ "ib1", "ib2" ] exportedToolbox appEmpty
          toolbox = currentToolbox imported

        imported.page `shouldEqual` Model.DefsPage
        imported.toast `shouldEqual` Just "Imported toolbox live defs"
        toolbox.id `shouldEqual` "tbx-import"
        map _.id toolbox.blocks `shouldEqual` [ "ib1", "ib2" ]
        map _.applied toolbox.blocks `shouldEqual` [ "ok = sound \"bd\"", "" ]

      it "keeps duplicated scores normalized for many score shapes" do
        quickCheck do
          bits <- genScore
          pure
            let
              score = normalizeScore bits
              source = appWithSong { songs = [ (currentSong appWithSong) { tracks = [ (trackById "t1" appWithSong) { score = score } ] } ] }
              copy = currentSong
                ( Reducer.duplicateSong "s1"
                    { songId: "s-copy", trackIds: [ "nt1" ], cellIds: [ "nc1", "nc2" ] }
                    source
                )
            in
              all (\track -> length track.score == totalBars) copy.tracks

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

genScore :: Gen.Gen (Array Boolean)
genScore =
  Array.take 32 <$> Gen.arrayOf ((_ == 1) <$> Gen.chooseInt 0 1)

appEmpty :: Model.App
appEmpty =
  Model.defaultApp

appWithSong :: Model.App
appWithSong =
  Model.defaultApp
    { songs = [ sampleSong ]
    , currentSongId = Just "s1"
    }

appWithToolbox :: Model.App
appWithToolbox =
  Model.defaultApp
    { toolboxes =
        [ { id: "tbx1"
          , name: "live defs"
          , blocks:
              [ { id: "b1", name: "feel", code: "feel = (# room 0.4)", applied: "" }
              , { id: "b2", name: "broken", code: "broken = (# room 0.4", applied: "" }
              ]
          }
        ]
    , currentToolboxId = Just "tbx1"
    }

sampleSong :: Song
sampleSong =
  { id: "s1"
  , name: "midnight set"
  , tracks:
      [ ( track "t1" "drums"
            [ cell "c1" "d1 $ sound \"bd\""
            , cell "c2" "d1 $ sound \"cp\""
            ]
        )
          { active = Just "c1"
          , selected = Just "c2"
          , hue = 25
          , score = normalizeScore [ true, false ]
          }
      , ( track "t2" "lead"
            [ cell "c3" "d1 $ sound \"arpy\"" ]
        )
          { active = Just "c3"
          , selected = Just "c3"
          , hue = 95
          , score = normalizeScore []
          }
      , ( track "t3" "bad"
            [ cell "c4" "d1 $ sound \"bd"
            , cell "c5" "d1 $ sound \"hh\""
            ]
        )
          { active = Just "missing"
          , selected = Just "c4"
          , hue = 200
          , score = normalizeScore [ true ]
          }
      ]
  }

currentSong :: Model.App -> Song
currentSong app =
  case app.currentSongId >>= \id -> Array.find (_.id >>> (_ == id)) app.songs of
    Just s -> s
    Nothing -> sampleSong

currentTracks :: Model.App -> Array Track
currentTracks =
  _.tracks <<< currentSong

trackById :: String -> Model.App -> Track
trackById id app =
  case Array.find (_.id >>> (_ == id)) (currentTracks app) of
    Just t -> t
    Nothing -> track id "missing" []

currentToolbox :: Model.App -> Model.Toolbox
currentToolbox app =
  case app.currentToolboxId >>= \id -> Array.find (_.id >>> (_ == id)) app.toolboxes of
    Just toolbox -> toolbox
    Nothing -> Model.defaultToolbox "missing" "missing"

currentBlocks :: Model.App -> Array Model.Block
currentBlocks =
  _.blocks <<< currentToolbox

exportedSong :: ImportExport.ExportedSong
exportedSong =
  { riptideSong: 1
  , name: "imported set"
  , tracks:
      [ { name: "imported drums"
        , hue: Just 25
        , vol: Nothing
        , flt: Nothing
        , dly: Just 12
        , active: Just "old-c2"
        , selected: Just "old-c1"
        , score: [ true, false, true ]
        , cells:
            [ { id: "old-c1", code: "d1 $ sound \"bd\"" }
            , { id: "old-c2", code: "d1 $ sound \"cp\"" }
            ]
        }
      ]
  }

exportedToolbox :: ImportExport.ExportedToolbox
exportedToolbox =
  { riptideToolbox: 1
  , name: "live defs"
  , blocks:
      [ { name: "ok", code: "ok = sound \"bd\"" }
      , { name: "bad", code: "bad = sound \"bd" }
      ]
  }

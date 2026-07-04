module Test.Main where

import Prelude

import Data.Array (length)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (all)
import Data.Maybe (Maybe(..))
import Data.Number as Number
import Effect (Effect)
import Effect.Aff (launchAff_)
import Riptide.Action (ControlKey(..))
import Riptide.App as App
import Riptide.Helpers (cascade, collectIds, definedNames, duplicateIds, effectiveSelected, normalizeScore)
import Riptide.Model (Cell, Song, Track, totalBars)
import Riptide.Model as Model
import Riptide.Protocol.Client as Protocol
import Riptide.ImportExport as ImportExport
import Riptide.View.Playhead as Playhead
import Riptide.Reducer as Reducer
import Riptide.Validation (authoritativeValidation, valid)
import Test.Spec (describe, it)
import Test.Spec.Assertions (shouldEqual, shouldSatisfy)
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

      it "uses matching backend validation as authoritative and local syntax otherwise" do
        let
          backend =
            [ { source: "d1 $ sound \"bd\"", valid: false, error: Just "backend says no" }
            , { source: "d1 $ sound \"cp\"", valid: true, error: Nothing }
            ]

        authoritativeValidation backend "d1 $ sound \"bd\"" `shouldEqual`
          { empty: false, valid: false, error: Just "backend says no" }
        authoritativeValidation backend "d1 $ sound \"cp\"" `shouldEqual`
          { empty: false, valid: true, error: Nothing }
        authoritativeValidation backend "d1 $ sound \"hh\"" `shouldEqual`
          { empty: false, valid: true, error: Nothing }
        authoritativeValidation backend "d1 $ sound \"hh" `shouldEqual`
          { empty: false, valid: false, error: Just "unbalanced quote" }

    describe "connection state" do
      it "has renderable labels and backend gating" do
        Model.connectionLabel Model.Connecting `shouldEqual` "engine connecting"
        Model.connectionLabel Model.Connected `shouldEqual` "engine connected"
        Model.connectionLabel Model.Disconnected `shouldEqual` "engine offline"
        Model.connectionLabel (Model.ConnectionError "websocket error") `shouldEqual` "engine error"

        Model.canUseBackend Model.Connecting `shouldEqual` false
        Model.canUseBackend Model.Connected `shouldEqual` true
        Model.canUseBackend Model.Disconnected `shouldEqual` false
        Model.canUseBackend (Model.ConnectionError "websocket error") `shouldEqual` false

    describe "websocket protocol" do
      it "encodes client commands with backend tags and field names" do
        Protocol.encodeClientCommand (Protocol.ValidateText "d1 $ sound \"bd\"") `shouldEqual`
          "{\"type\":\"validateText\",\"text\":\"d1 $ sound \\\"bd\\\"\"}"
        Protocol.encodeClientCommand (Protocol.SetSession sampleProtocolSession) `shouldEqual`
          "{\"type\":\"setSession\",\"session\":{\"sessionSlotCapacity\":16,\"sessionTracks\":[{\"trackId\":\"t1\",\"trackName\":\"drums\",\"trackSlot\":1,\"trackTexts\":[{\"trackTextId\":\"c1\",\"trackTextSource\":\"d1 $ sound \\\"bd\\\"\"},{\"trackTextId\":\"c2\",\"trackTextSource\":\"d1 $ sound \\\"cp\\\"\"}],\"trackActiveText\":\"c1\",\"trackSelectedText\":\"c2\"}],\"sessionDefinitions\":[{\"blockId\":\"b1\",\"blockName\":\"feel\",\"blockCode\":\"feel = (# room 0.4)\",\"blockApplied\":\"feel = (# room 0.35)\"}]}}"
        Protocol.encodeClientCommand (Protocol.ActivateTrackText "track-a" "cell-1") `shouldEqual`
          "{\"type\":\"activateTrackText\",\"trackId\":\"track-a\",\"textId\":\"cell-1\"}"
        Protocol.encodeClientCommand (Protocol.SilenceTrack "track-a") `shouldEqual`
          "{\"type\":\"silenceTrack\",\"trackId\":\"track-a\"}"
        Protocol.encodeClientCommand (Protocol.SaveTrackText "track-a" "cell-1" "d1 $ sound \"cp\"") `shouldEqual`
          "{\"type\":\"saveTrackText\",\"trackId\":\"track-a\",\"textId\":\"cell-1\",\"text\":\"d1 $ sound \\\"cp\\\"\"}"
        Protocol.encodeClientCommand (Protocol.SaveDefinition "block-1" "feel" "feel = (# room 0.4)") `shouldEqual`
          "{\"type\":\"saveDefinition\",\"definitionId\":\"block-1\",\"name\":\"feel\",\"code\":\"feel = (# room 0.4)\"}"
        Protocol.encodeClientCommand (Protocol.ApplyDefinition "block-1") `shouldEqual`
          "{\"type\":\"applyDefinition\",\"definitionId\":\"block-1\"}"

      it "decodes server events with session snapshots and validation results" do
        Protocol.decodeServerEvent
          "{\"type\":\"stateSnapshot\",\"session\":{\"sessionSlotCapacity\":4,\"sessionTracks\":[{\"trackId\":\"track-a\",\"trackName\":\"drums\",\"trackSlot\":1,\"trackTexts\":[{\"trackTextId\":\"cell-1\",\"trackTextSource\":\"d1 $ sound \\\"bd\\\"\"}],\"trackActiveText\":\"cell-1\",\"trackSelectedText\":null}],\"sessionDefinitions\":[{\"blockId\":\"block-1\",\"blockName\":\"feel\",\"blockCode\":\"feel = (# room 0.4)\",\"blockApplied\":\"\"}]}}" `shouldEqual`
          Right
            ( Protocol.StateSnapshot
                { sessionSlotCapacity: 4
                , sessionTracks:
                    [ { trackId: "track-a"
                      , trackName: "drums"
                      , trackSlot: 1
                      , trackTexts:
                          [ { trackTextId: "cell-1"
                            , trackTextSource: "d1 $ sound \"bd\""
                            }
                          ]
                      , trackActiveText: Just "cell-1"
                      , trackSelectedText: Nothing
                      }
                    ]
                , sessionDefinitions:
                    [ { blockId: "block-1"
                      , blockName: "feel"
                      , blockCode: "feel = (# room 0.4)"
                      , blockApplied: ""
                      }
                    ]
                }
            )
        Protocol.decodeServerEvent "{\"type\":\"textValidated\",\"result\":{\"type\":\"validationSucceeded\",\"text\":\"d1 $ sound \\\"bd\\\"\"}}" `shouldEqual`
          Right (Protocol.TextValidated (Protocol.ValidationSucceeded "d1 $ sound \"bd\""))
        Protocol.decodeServerEvent "{\"type\":\"textValidated\",\"result\":{\"type\":\"validationFailed\",\"text\":\"d1 $ sound \\\"bd\",\"message\":\"unbalanced quote\"}}" `shouldEqual`
          Right (Protocol.TextValidated (Protocol.ValidationFailed "d1 $ sound \"bd" "unbalanced quote"))
        Protocol.decodeServerEvent "{\"type\":\"commandFailed\",\"failure\":{\"command\":{\"type\":\"silenceTrack\",\"trackId\":\"track-a\"},\"message\":\"track not found\"}}" `shouldEqual`
          Right (Protocol.CommandFailed { command: Protocol.SilenceTrack "track-a", message: "track not found" })

      it "prepares the full current editor state as the first open command" do
        App.commandsForSocketOpen appWithSongAndToolbox `shouldEqual`
          [ Protocol.SetSession sampleProtocolSession ]

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

      it "cancels an armed destructive action without deleting the target" do
        let
          armed = Reducer.removeCell "t1" "c2" appWithSong
          cancelled = Reducer.cancelConfirm armed
          rearmed = Reducer.removeCell "t1" "c2" cancelled
          deleted = Reducer.removeCell "t1" "c2" rearmed

        armed.confirm `shouldEqual` Just "cell:c2"
        cancelled.confirm `shouldEqual` Nothing
        map (_.id) (trackById "t1" cancelled).cells `shouldEqual` [ "c1", "c2" ]
        rearmed.confirm `shouldEqual` Just "cell:c2"
        map (_.id) (trackById "t1" deleted).cells `shouldEqual` [ "c1" ]

      it "adds tracks and cells with explicit ids and normalized scores" do
        let
          app = Reducer.addCell "t1" "c7" (Reducer.addTrack "t4" appWithSong)
          addedTrack = trackById "t4" app

        map (_.id) (trackById "t1" app).cells `shouldEqual` [ "c1", "c2", "c7" ]
        (Reducer.setCtrl "t4" Vol 42 app # trackById "t4").vol `shouldEqual` 42
        addedTrack.name `shouldEqual` "track 4"
        addedTrack.hue `shouldEqual` 285
        length addedTrack.score `shouldEqual` totalBars

      it "moves a track before another track in the current song" do
        let
          moved = Reducer.moveTrack "t3" "t1" appWithSong

        map (_.id) (currentTracks moved) `shouldEqual` [ "t3", "t1", "t2" ]
        map (_.id) (trackById "t3" moved).cells `shouldEqual` [ "c4", "c5" ]

      it "moves a cell before another cell on the same track" do
        let
          moved = Reducer.moveCell "t1" "c2" "t1" (Just "c1") appWithSong
          track' = trackById "t1" moved

        map (_.id) track'.cells `shouldEqual` [ "c2", "c1" ]
        track'.active `shouldEqual` Just "c1"
        track'.selected `shouldEqual` Just "c2"

      it "moves a cell across tracks, preserves its id, and clears source active refs" do
        let
          moved = Reducer.moveCell "t2" "c3" "t1" Nothing appWithSong
          source = trackById "t2" moved
          dest = trackById "t1" moved

        map (_.id) dest.cells `shouldEqual` [ "c1", "c2", "c3" ]
        map (_.id) source.cells `shouldEqual` []
        source.active `shouldEqual` Nothing
        source.selected `shouldEqual` Nothing
        dest.selected `shouldEqual` Just "c2"

      it "applies only valid toolbox blocks" do
        let
          once = Reducer.applyBlock "b1" appWithToolbox
          allApplied = Reducer.applyAll once

        map _.applied (currentBlocks once) `shouldEqual` [ "feel = (# room 0.4)", "" ]
        map _.applied (currentBlocks allApplied) `shouldEqual` [ "feel = (# room 0.4)", "" ]

    describe "automation and score helpers" do
      it "derives playback commands only for changed active cells" do
        Reducer.playbackCommandsForActiveTransitions
          [ (trackById "t1" appWithSong) { active = Nothing }
          , trackById "t2" appWithSong
          , trackById "t3" appWithSong
          ]
          [ (trackById "t1" appWithSong) { active = Just "c2" }
          , trackById "t2" appWithSong
          , (trackById "t3" appWithSong) { active = Nothing }
          ]
          `shouldEqual`
            [ Protocol.ActivateTrackText "t1" "c2"
            , Protocol.SilenceTrack "t3"
            ]

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

      it "steps the playhead with capped frame time, loop wrapping, and bar-change reporting" do
        let
          capped =
            Playhead.step
              { playhead: 3.0
              , dtSeconds: 0.5
              , loopOn: true
              , loopStart: 2
              , loopEnd: 6
              , lastBar: 3
              }
          wrapped =
            Playhead.step
              { playhead: 5.95
              , dtSeconds: 0.25
              , loopOn: true
              , loopStart: 2
              , loopEnd: 6
              , lastBar: 5
              }
          fullRange =
            Playhead.step
              { playhead: 15.95
              , dtSeconds: 0.25
              , loopOn: false
              , loopStart: 2
              , loopEnd: 6
              , lastBar: 15
              }

        near capped.playhead 3.15625 `shouldSatisfy` identity
        capped.bar `shouldEqual` 3
        capped.changedBar `shouldEqual` Nothing

        near wrapped.playhead 2.10625 `shouldSatisfy` identity
        wrapped.bar `shouldEqual` 2
        wrapped.changedBar `shouldEqual` Just 2

        near fullRange.playhead 0.10625 `shouldSatisfy` identity
        fullRange.bar `shouldEqual` 0
        fullRange.changedBar `shouldEqual` Just 0

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

near :: Number -> Number -> Boolean
near actual expected =
  Number.abs (actual - expected) <= 0.000001

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

appWithSongAndToolbox :: Model.App
appWithSongAndToolbox =
  Model.defaultApp
    { songs =
        [ { id: "s-open"
          , name: "open song"
          , tracks:
              [ ( track "t1" "drums"
                    [ cell "c1" "d1 $ sound \"bd\""
                    , cell "c2" "d1 $ sound \"cp\""
                    ]
                )
                  { active = Just "c1"
                  , selected = Just "c2"
                  }
              ]
          }
        ]
    , currentSongId = Just "s-open"
    , toolboxes =
        [ { id: "tb-open"
          , name: "open defs"
          , blocks:
              [ { id: "b1"
                , name: "feel"
                , code: "feel = (# room 0.4)"
                , applied: "feel = (# room 0.35)"
                }
              ]
          }
        ]
    , currentToolboxId = Just "tb-open"
    }

sampleProtocolSession :: Protocol.Session
sampleProtocolSession =
  { sessionSlotCapacity: Model.totalBars
  , sessionTracks:
      [ { trackId: "t1"
        , trackName: "drums"
        , trackSlot: 1
        , trackTexts:
            [ { trackTextId: "c1", trackTextSource: "d1 $ sound \"bd\"" }
            , { trackTextId: "c2", trackTextSource: "d1 $ sound \"cp\"" }
            ]
        , trackActiveText: Just "c1"
        , trackSelectedText: Just "c2"
        }
      ]
  , sessionDefinitions:
      [ { blockId: "b1"
        , blockName: "feel"
        , blockCode: "feel = (# room 0.4)"
        , blockApplied: "feel = (# room 0.35)"
        }
      ]
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

# Issue 17 Plan: Tidal Stream Playback

## Current Code

- `Riptide.Session` owns pure session state, hidden slots, track activation,
  and silencing. It is read-only for this ticket.
- `Riptide.Eval` interprets or validates track text as a Tidal
  `ControlPattern`, including applied definition scope.
- The library links `tidal-1.10.1`. Local API discovery shows:
  - `Sound.Tidal.Stream.startTidal :: Target -> Config -> IO Stream`
  - `Sound.Tidal.Stream.streamReplace :: Stream -> ID -> ControlPattern -> IO ()`
  - `Sound.Tidal.Stream.streamSilence :: Stream -> ID -> IO ()`
  - `Sound.Tidal.Stream.Target.superdirtTarget :: Target`
  - `Sound.Tidal.Stream.Types.Target` has `oAddress` and `oPort` fields.
  - `Sound.Tidal.ID.ID :: String -> ID`

## Design

Add a new `Riptide.Playback` module with a small backend interface:

- `PlaybackBackend` stores `replaceSlot :: Slot -> ControlPattern -> IO ()`
  and `silenceSlot :: Slot -> IO ()`.
- `activateTrackPlayback` accepts a backend and a `Session`/`TrackId`, locates
  the active text for that track, interprets the text with applied definitions,
  and calls `replaceSlot` with the track's `Slot`.
- `silenceTrackPlayback` accepts a backend and a `Session`/`TrackId`, locates
  the track, and calls `silenceSlot` with the track's `Slot`.
- `DryPlaybackBackend` records operations in an `IORef`, giving tests an
  audio-free proof boundary.
- `PlaybackConfig` is read from environment variables:
  - `RIPTIDE_SUPERDIRT_HOST`
  - `RIPTIDE_SUPERDIRT_PORT`
  Both must be present for real OSC. If neither is present, use dry playback.
  If one is invalid/missing, return a config error.
- The real Tidal backend starts `startTidal` with
  `superdirtTarget{oAddress = host, oPort = port}` and uses
  `streamReplace`/`streamSilence` with slot IDs like `d1`, `d2`.

## Slices

### Slice A: Dry Playback Wiring

Introduce `Riptide.Playback` with the backend interface, dry recorder,
activation/silence orchestration, unit tests, cabal module wiring, and
`gate.sh`.

This slice should remain audio-free and does not start a Tidal stream.

### Slice B: Real Tidal Backend And Config

Extend `Riptide.Playback` with environment parsing and real Tidal stream
construction. Tests cover dry default, configurable host/port parsing, invalid
port errors, and that the real target builder preserves remote host values.

This slice may import Tidal Stream modules, but tests must not instantiate the
real stream unless explicitly configured by the caller.

## Verification

Run `./gate.sh` after each accepted slice. Before completion, push the branch,
open/update a draft PR against `main`, and verify GitHub Actions reports 4/4
successful jobs.

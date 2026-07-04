# Issue 18 Spec: Websocket Server And Wire Protocol

## User Story

As the riptide frontend, I need a single-origin backend server that owns the live
session, validates and plays tracks, persists edits, and broadcasts full state
updates so the browser UI can drive a remote Tidal mixer.

## Functional Requirements

- The backend exposes a websocket endpoint, `/ws`, with a JSON protocol for
  client commands and server events.
- On websocket connect, the server sends the full current `Session` snapshot.
- After every successful state-changing command, the server broadcasts a fresh
  full-state snapshot to every connected client.
- The protocol supports validation of arbitrary track text against the currently
  applied definitions through `Riptide.Eval`.
- The protocol supports activating a track text and silencing a track through
  `Riptide.Playback`, using dry playback in tests and configured playback at
  runtime.
- The protocol supports saving track text, saving definition blocks, and
  applying definition blocks, persisting the relevant store through
  `Riptide.Store`.
- The server loads definitions before tracks from the configured state
  directory on startup.
- The HTTP server serves the frontend static bundle from
  `RIPTIDE_FRONTEND_DIR`, defaulting to `frontend/dist`, and upgrades `/ws` to
  websockets.
- The executable keeps the existing `eval` smoke command and adds `serve`.
- Host and port are configurable through `RIPTIDE_HOST` and `RIPTIDE_PORT`.

## Non-Functional Requirements

- The server is an impure shell around the existing pure domain reducers; do not
  modify `Riptide.Session`, `Riptide.Store`, `Riptide.Eval`, or
  `Riptide.Playback`.
- CI must not require live SuperDirt or audio.
- Protocol JSON round-trips are covered by QuickCheck.
- Command dispatch is testable without a live websocket, using dry playback.
- `./gate.sh` remains the final proof and must run successfully before the PR is
  marked complete.

## Success Criteria

- `cabal test unit-tests` includes protocol round-trip properties and server
  command dispatch tests.
- `riptide serve` starts a Warp server with static file serving and websocket
  upgrade on `/ws`.
- `./gate.sh` passes locally.
- A draft PR exists against `main`, with CI reporting 4/4 green before
  completion.

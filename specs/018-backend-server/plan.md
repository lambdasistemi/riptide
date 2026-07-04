# Issue 18 Plan: Websocket Server And Wire Protocol

## Architecture

- Add `Riptide.Protocol` for the shared JSON wire types:
  `ClientCommand`, `ServerEvent`, validation result/error shapes, and any small
  request identifiers needed by the frontend. Use `Session`, `TrackId`,
  `TextId`, `DefinitionId`, and domain records directly where practical because
  they already have `aeson` instances.
- Add `Riptide.Server` for the live server shell:
  - an `MVar` or STM variable for the current `Session`;
  - a registry of connected websocket clients;
  - a command handler that can be unit-tested without sockets;
  - Warp/WAI static serving with `/ws` websocket upgrade.
- Extend `app/Main.hs` with `serve`, preserving `eval`.
- Extend `riptide.cabal` only additively for server dependencies and new test
  modules.

## Runtime Configuration

- `RIPTIDE_HOST`, default `127.0.0.1`.
- `RIPTIDE_PORT`, default `3000`.
- `RIPTIDE_FRONTEND_DIR`, default `frontend/dist`.
- State directory may default to a local/state path chosen in `Riptide.Server`;
  keep it explicit in the server config so tests can point at temporary stores.
- Playback mode comes from the existing `Riptide.Playback.readPlaybackMode`.

## Command Dispatch

- `ValidateText` evaluates only the supplied text against
  `blockApplied` definitions from the current session and returns an ok/error
  event to the caller.
- `ActivateText track text` first updates the session with
  `activateTrackText`, then calls `activateTrackPlayback` with the updated
  session. If playback fails, report the error and do not broadcast a misleading
  success event.
- `SilenceTrack track` calls `silenceTrackPlayback`, then updates the session
  with `silenceTrack`.
- `SaveTrackText track text source` updates the session and persists tracks.
- `SaveDefinition id name code` updates the session and persists definitions.
- `ApplyDefinition id` updates the session and persists definitions.

## Slice Breakdown

1. Protocol and tests: introduce `Riptide.Protocol`, cabal module wiring, and
   QuickCheck JSON round-trip coverage.
2. Server command dispatch: introduce `Riptide.Server` state/config types and
   testable command handling with dry playback and store persistence.
3. Websocket/static executable wiring: implement Warp websocket/static serving,
   add `serve` in `app/Main.hs`, and cover the executable/server startup surface
   with unit-testable pieces where practical.

## Verification

- Focused slice commands:
  - `nix develop --quiet -c just unit Riptide.Protocol`
  - `nix develop --quiet -c just unit Riptide.Server`
  - `nix develop --quiet -c just build`
- Final command: `./gate.sh`.

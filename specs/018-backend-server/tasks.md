# Issue 18 Tasks

## Slice 1 — Protocol Types And Round-Trips

- [X] T018-S1 Define `Riptide.Protocol` client command and server event JSON
  types covering snapshot, validation, activation, silence, save track text,
  save definition, and apply definition.
- [X] T018-S1 Add cabal exposure and test-suite wiring for protocol tests.
- [X] T018-S1 Add QuickCheck encode/decode round-trip properties for protocol
  commands and events.
- [X] T018-S1 Run the focused protocol test command and commit the slice.

## Slice 2 — Server Command Dispatch

- [X] T018-S2 Define `Riptide.Server` server state/config and a socket-free
  command handler around the existing session reducers, store functions, eval,
  and playback backend.
- [X] T018-S2 Add command dispatch tests using dry playback and temporary store
  directories.
- [X] T018-S2 Ensure successful state-changing commands broadcast/surface a
  fresh snapshot and persist the relevant stores.
- [X] T018-S2 Run the focused server test command and commit the slice.

## Slice 3 — Warp/Websocket Serve Mode

- [X] T018-S3 Implement websocket client registration, connect snapshot, command
  receive loop, broadcast snapshots, and static frontend serving on one origin.
- [X] T018-S3 Add `riptide serve` while preserving `riptide eval`.
- [X] T018-S3 Add required cabal dependencies for Warp, WAI static serving, and
  websockets.
- [X] T018-S3 Run `./gate.sh` and commit the slice.

## Finalization

- [ ] T018-F1 Open a draft PR against `main`.
- [ ] T018-F1 Verify PR CI is 4/4 green.
- [ ] T018-F1 Append `COMPLETE <pr-url> sha=<sha> ci=4/4` to the ticket status.

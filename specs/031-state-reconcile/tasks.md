# Tasks: Client State Reconcile On Connect

## Slice 1 - Backend Protocol And Handler

- [X] T031-S1 Add `SetSession` command JSON support in `src/Riptide/Protocol.hs`.
- [X] T031-S1 Handle the command in `src/Riptide/Server.hs` by replacing tracks
  and definitions, preserving slot capacity, persisting via `saveSession`, and
  broadcasting a snapshot.
- [X] T031-S1 Add backend tests for protocol round-trip and server persistence.
- [X] T031-S1 Run focused backend tests and `./gate.sh`.
- [X] T031-S1 Commit as `fix(backend): reconcile client session state`.

## Slice 2 - Frontend Handshake

- [X] T031-S2 Add PureScript protocol support for the state command and exact
  JSON encoding.
- [X] T031-S2 Send the current app tracks and definitions on websocket open
  before connected playback transitions.
- [X] T031-S2 Add frontend tests for command encoding and connect-handshake
  ordering.
- [X] T031-S2 Run focused frontend tests and `./gate.sh`.
- [X] T031-S2 Commit as `fix(frontend): push state on websocket connect`.

## Finalization

- [X] T031-F1 Verify the full gate at HEAD.
- [ ] T031-F1 Open a draft PR against `main` and confirm PR CI reports 4/4 green.

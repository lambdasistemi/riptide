# Specification: Client State Reconcile On Connect

## User Story

When a performer opens the served riptide UI, the server session must mirror the
editor state that the client boots with before any playback command is sent.
Fresh page load must not surface `PlaybackTrackMissing` for tracks that exist in
the UI seed but not yet in the server store.

## Functional Requirements

- Add a client-to-server command that carries the client's current tracks and
  definitions as one state payload.
- On receipt, the server replaces its session tracks and definitions with the
  payload, preserves the server-configured slot capacity, persists both stores,
  and broadcasts a state snapshot.
- On every websocket connect or reconnect, the frontend sends the state command
  before any activate or silence command can be emitted from the connected
  session.
- The command JSON shape is stable across Haskell and PureScript encoders and
  decoders.
- Existing validation, save, apply, activate, and silence behavior remains
  unchanged.

## Success Criteria

- Backend protocol round-trip tests cover the new command.
- Backend server tests prove the command replaces tracks and definitions and
  writes both stores.
- Frontend tests cover the new command encoding and the connect-handshake command
  order.
- `./gate.sh` passes, including frontend render smoke.
- Opening a served UI against an empty state directory does not show a
  `Command failed: PlaybackTrackMissing ...` toast/banner on fresh connect.

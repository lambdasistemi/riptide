# Plan: Client State Reconcile On Connect

## Context

The backend websocket sends a server snapshot immediately after accept, then
processes commands. The frontend ignores that snapshot and continues from
`seedApp`. On a fresh server store, playback transitions can reference client
track ids such as `t2` before the server has any corresponding tracks.

The chosen direction is client-as-editor/source-of-truth. The client pushes its
current editable state to the server on websocket open.

## Wire Shape

Add a `ClientCommand` constructor:

```text
SetSession Session
```

JSON:

```json
{
  "type": "setSession",
  "session": {
    "sessionSlotCapacity": 16,
    "sessionTracks": [],
    "sessionDefinitions": []
  }
}
```

Server handling preserves its configured `sessionSlotCapacity` and replaces only
`sessionTracks` and `sessionDefinitions` from the payload before calling
`saveSession`.

## Slice 1: Backend Protocol And Handler

Owned files:

- `src/Riptide/Protocol.hs`
- `src/Riptide/Server.hs`
- `test/Riptide/ProtocolSpec.hs`
- `test/Riptide/ServerSpec.hs`

Add the command, JSON round-trip coverage, and server persistence test. Do not
edit `Session.hs`, `Store.hs`, `Eval.hs`, or `Playback.hs`.

## Slice 2: Frontend Command And Connect Handshake

Owned files:

- `frontend/src/Riptide/Protocol/Client.purs`
- `frontend/src/Riptide/App.purs`
- `frontend/test/Main.purs`

Add the PureScript command, encoder/decoder support, app-to-session mapping,
and send it on `WebSocketOpened` before any connected playback command path can
run. Tests should assert the encoded JSON shape and that connect-open commands
start with `SetSession`.

## Verification

Run `./gate.sh` at the end of each slice. After the final slice, also run a
fresh `riptide serve` smoke when practical and confirm no `CommandFailed` text
appears in the served UI.

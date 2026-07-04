# Plan: frontend-backend websocket integration

## Current Shape

The backend in `src/Riptide/Protocol.hs` exposes a tagged JSON websocket
protocol and `src/Riptide/Server.hs` serves `/ws` plus the static frontend. The
frontend is a pure Halogen mock: `App.purs` owns effects, `Reducer.purs` owns
local state transforms, and views compute validity through
`Riptide.Validation.valid`.

## Approach

Add an effectful frontend client layer without replacing the pure core. The
client layer owns JSON codecs and websocket FFI. `App.purs` subscribes to socket
events, keeps connection/validation state in the app model, and sends commands
at user action boundaries. Existing reducer functions remain the fallback path
for disconnected/static use.

Use additive PureScript dependencies only. Prefer `argonaut` for codec tests and
either the registry `web-socket` package or a minimal sibling `.js` FFI for the
browser `WebSocket` API. No Haskell backend files are edited.

## Slice 1: Protocol and websocket client foundation

Create frontend protocol/client modules that compile independently of the app:

- `Riptide.Protocol.Client` or equivalent PureScript module for
  `ClientCommand`, `ServerEvent`, `ValidationResult`, `CommandFailure`, session
  snapshot types, and exact Argonaut encoders/decoders.
- `Riptide.WebSocket` plus optional `.js` FFI for same-origin `/ws`, send,
  close, and event callbacks.
- Frontend tests covering representative command encoding and server event
  decoding.
- `frontend/spago.yaml` and `frontend/spago.lock` updated additively.

Proof: `nix develop .#frontend -c just test` and `nix build .#frontend`.

## Slice 2: App connection state and authoritative validation

Wire the websocket client into Halogen initialization and event handling:

- Extend `Model.App` with connection state, validation cache keyed by source or
  cell/block identity, and command failure/toast state as needed.
- Replace engine boolean meaning with websocket status while preserving
  disconnected fallback behavior.
- On text edits, keep local syntactic validity as the immediate hint and send
  `saveTrackText`/`validateText` when connected.
- On definition edits/apply, send `saveDefinition`/`applyDefinition` when
  connected, then revalidate affected current text where practical.
- Views display backend validation when present and local validation otherwise.

Proof: frontend tests, frontend build, and a documented offline smoke that the
static app still loads with disconnected status.

## Slice 3: Real activate/silence and score playback commands

Send backend playback commands from all launch boundaries:

- Manual cell launch/stop sends `activateTrackText` or `silenceTrack` when
  connected. Disconnected fallback remains the current reducer behavior.
- `Hush` sends silence for active tracks when connected and still clears local
  state.
- Client-side score automation detects bar changes, preserves local playhead
  timing, and sends activate/silence commands for transitions caused by painted
  regions.
- Command failures are surfaced without crashing and do not break fallback use.

Proof: frontend tests where practical, `./gate.sh`, and a live smoke against
`riptide serve` in dry playback mode.

## Finalization

After all slices are accepted, update the draft PR body, run `./gate.sh`, push,
confirm all four GitHub CI jobs are green, then drop `gate.sh` in the ready
commit per the ticket process.

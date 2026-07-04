# Tasks: frontend-backend websocket integration

## Slice 1 - Protocol and websocket client foundation

- [ ] T019-S1 Define exact PureScript client/server protocol types and
  Argonaut codecs matching `src/Riptide/Protocol.hs` and
  `src/Riptide/Session.hs`.
- [ ] T019-S1 Add a browser websocket client module/FFI that connects to
  same-origin `/ws`, reports open/close/error/message, sends encoded commands,
  and never throws uncaught errors to Halogen.
- [ ] T019-S1 Update frontend PureScript dependencies and lockfile
  additively.
- [ ] T019-S1 Add focused frontend tests for command encoding and event
  decoding.
- [ ] T019-S1 Run the focused frontend test/build proof and commit with
  `Tasks: T019-S1`.

## Slice 2 - App connection state and authoritative validation

- [ ] T019-S2 Extend app state/actions to track websocket connection status,
  backend validation results, and command failures while keeping disconnected
  fallback behavior.
- [ ] T019-S2 Wire app initialization to connect/subscribe to `/ws`, process
  decoded server events, and reflect connection state in the existing engine UI.
- [ ] T019-S2 Send save/validate commands for cell edits and definition
  save/apply operations when connected.
- [ ] T019-S2 Update song/definition/shell views so backend validation is
  authoritative when present and local syntactic validation remains the instant
  hint.
- [ ] T019-S2 Run focused tests/build proof and commit with `Tasks: T019-S2`.

## Slice 3 - Real activate/silence and score playback commands

- [ ] T019-S3 Send `activateTrackText`/`silenceTrack` commands for manual cell
  launch, stop, and hush when connected.
- [ ] T019-S3 Preserve client-side score timing while sending backend
  activate/silence commands when the playhead enters or leaves painted regions.
- [ ] T019-S3 Surface backend `commandFailed` events without crashing and keep
  disconnected/static fallback behavior usable.
- [ ] T019-S3 Run `./gate.sh`, document the offline/static and live
  `riptide serve` smoke evidence, and commit with `Tasks: T019-S3`.

## Finalization

- [ ] T019-F1 Review the full diff, run `./gate.sh`, push the branch, open a
  draft PR against `main`, and confirm the PR body matches delivered behavior.
- [ ] T019-F1 Confirm GitHub CI is 4/4 green.
- [ ] T019-F1 Drop `gate.sh` in the final ready-for-review commit and mark the
  PR ready.

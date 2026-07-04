# Tasks

## Slice 1 - backend CORS

- [X] T039-S1 Add CORS origins to server config with permissive default and env parsing.
- [X] T039-S1 Add CORS headers to HTTP responses and implement successful `OPTIONS` preflight.
- [X] T039-S1 Preserve websocket upgrades without rejecting cross-origin `Origin`.
- [X] T039-S1 Add backend tests for config, preflight, foreign-origin headers, and cross-origin websocket acceptance.
- [X] T039-S1 Run focused backend tests and `./gate.sh`, then commit with the required trailer.

## Slice 2 - frontend backend setting

- [ ] T039-S2 Add persisted backend host/URL state and localStorage FFI.
- [ ] T039-S2 Build websocket URLs from the setting, preserving same-origin behavior when empty.
- [ ] T039-S2 Add shell/top-bar settings UI for the backend host/URL field.
- [ ] T039-S2 Reconnect on setting changes while preserving connection status behavior.
- [ ] T039-S2 Add frontend tests for URL derivation and storage round-trip.
- [ ] T039-S2 Update render smoke for the settings affordance and configured websocket connection.
- [ ] T039-S2 Run focused frontend tests and `./gate.sh`, then commit with the required trailer.

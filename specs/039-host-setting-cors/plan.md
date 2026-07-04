# Implementation Plan

## Tech stack

- Haskell backend using WAI, Warp, wai-websockets, and websockets.
- PureScript Halogen frontend with a JavaScript FFI websocket/localStorage boundary.
- Existing `./gate.sh` for build, unit, formatting, hlint, frontend nix build, and Chromium render smoke.

## Slice 1: backend CORS

Owned implementation surface:

- `src/Riptide/Server.hs`
- `test/Riptide/ServerSpec.hs`
- `riptide.cabal` if direct dependencies are needed for tests or HTTP status/header helpers.

Expected changes:

- Extend `ServerConfig` with configured CORS origins, defaulting to `["*"]`.
- Read `RIPTIDE_CORS_ORIGINS`, accepting a comma-separated list and preserving `*`.
- Wrap the WAI application with CORS headers and an `OPTIONS` preflight response.
- Preserve websocket upgrade handling through `websocketsOr` and do not add Origin rejection.
- Add focused backend tests for default/config parsing, CORS headers on HTTP responses, preflight, and cross-origin websocket upgrade acceptance.

## Slice 2: frontend backend setting

Owned implementation surface:

- `frontend/src/Riptide/**`
- `frontend/test/**`
- `frontend/spago.yaml` only if a direct dependency is genuinely needed.
- `gate.sh` only for render-smoke assertions of the new setting affordance and reconnect behavior.
- `frontend/dist/index.html` for CSS.

Expected changes:

- Add backend URL/host state to `App` and seed/default state.
- Add localStorage FFI for loading/saving the backend setting.
- Refactor websocket URL building so it is testable and uses the configured setting.
- On app initialization, load the stored backend setting before connecting.
- Add shell/top-bar settings UI with a visible settings control and backend host/URL field.
- On setting change, persist, close the existing socket, set connection to Connecting when the engine is enabled, and subscribe a new websocket using the new URL.
- Add PureScript tests for URL derivation and storage round-trip.
- Update render smoke to assert the settings control exists and that changing the input attempts a websocket connection to the configured host while preserving existing interaction checks.

## Verification

- Slice 1 focused command: `nix develop --command just unit Riptide.Server`.
- Slice 2 focused command: `nix develop .#frontend --command just --justfile frontend/justfile test`.
- Final command for every accepted implementation commit: `./gate.sh`.
- Manual/live smoke before final completion: run `riptide serve`, open the served UI in a browser, set the backend host field to the local server host, confirm connection status changes to connected, and confirm CORS preflight headers with `curl -i -X OPTIONS`.

# Issue 39: backend host setting and CORS

## P1 user story

As an operator serving the riptide UI from one origin and the backend from a tailnet host, I need the UI to remember which backend to connect to and the backend to accept cross-origin HTTP and websocket traffic.

## Scope

- Add configurable backend CORS behavior to the Haskell server.
- Add a top-bar settings affordance to the frontend for a backend host or websocket URL.
- Persist the frontend setting in `localStorage`.
- Reconnect the websocket when the setting changes.
- Preserve existing same-origin behavior when the setting is empty.

## Functional requirements

- FR-039-001: `RIPTIDE_CORS_ORIGINS` is read into server configuration and defaults to permissive `*`.
- FR-039-002: HTTP responses include CORS headers, including origin, methods, and headers.
- FR-039-003: `OPTIONS` preflight requests return a successful empty response with CORS headers.
- FR-039-004: Cross-origin websocket upgrades to `/ws` are accepted; server code must not reject based on the `Origin` header.
- FR-039-005: The frontend exposes a small shell/top-bar settings control containing a backend host or URL input.
- FR-039-006: Empty backend setting builds the current same-origin `/ws` URL.
- FR-039-007: A host:port setting such as `100.111.19.2:8201` builds `ws://100.111.19.2:8201/ws` or `wss://.../ws` when the page is HTTPS.
- FR-039-008: A full `ws://.../ws` or `wss://.../ws` setting is used as provided.
- FR-039-009: The setting round-trips through `localStorage`.
- FR-039-010: Changing the setting closes the current socket, stores the value, shows connecting/offline status through the existing connection state, and reconnects.

## Success criteria

- Backend unit tests cover CORS config/defaults, preflight headers, foreign-origin headers, and cross-origin websocket acceptance.
- Frontend tests cover URL derivation and storage round-trip.
- Render smoke covers the settings affordance and remains green for existing interactions.
- `./gate.sh` passes locally.
- PR CI is 4/4 green.

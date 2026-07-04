# Specification: frontend-backend websocket integration

## User Story

As a Riptide performer, I want the Halogen frontend to connect to the local
Riptide backend over `/ws` so validation, launching, and silencing use the real
Tidal-backed engine when it is available, while the static Pages build continues
to work as the current mock when no backend is present.

## Functional Requirements

- FR-001: The frontend must open a websocket to `/ws` on the same origin and
  expose connection state to the app as connected, connecting, disconnected, or
  failed.
- FR-002: Client commands must encode exactly like `Riptide.Protocol`
  `ClientCommand`: tagged JSON objects with `type` and the named fields
  `text`, `trackId`, `textId`, `definitionId`, `name`, and `code`.
- FR-003: Server events must decode exactly like `Riptide.Protocol`
  `ServerEvent`, including `stateSnapshot`, `textValidated`, and
  `commandFailed`.
- FR-004: The engine chip/control must reflect websocket connection state. The
  existing control stays in the UI, but connected/disconnected comes from the
  socket rather than a pure boolean toggle.
- FR-005: Local syntactic validation remains available as an instant optimistic
  hint. When connected, backend `TextValidated ValidationResult` responses are
  authoritative for matching source text.
- FR-006: Editing cell text must save the text to the backend when connected and
  request validation for the edited source.
- FR-007: Applying definition blocks must save/apply definitions against the
  backend when connected, so later validations use live applied definitions.
- FR-008: Launching/stopping a cell must send `activateTrackText` or
  `silenceTrack` when connected and fall back to current local state mutation
  when disconnected.
- FR-009: Score timing remains client-side. When the playhead crosses painted
  bars, the frontend updates its local active state and also sends the matching
  backend activate/silence command when connected.
- FR-010: Websocket failures, malformed events, command failures, and no-backend
  Pages usage must not crash the app. The app must show disconnected/fallback
  status and keep the mock workflow usable.

## Wire Shapes

Client commands:

- `{"type":"validateText","text":<source>}`
- `{"type":"activateTrackText","trackId":<trackId>,"textId":<cellId>}`
- `{"type":"silenceTrack","trackId":<trackId>}`
- `{"type":"saveTrackText","trackId":<trackId>,"textId":<cellId>,"text":<source>}`
- `{"type":"saveDefinition","definitionId":<blockId>,"name":<name>,"code":<code>}`
- `{"type":"applyDefinition","definitionId":<blockId>}`

Server events:

- `{"type":"stateSnapshot","session":<Session>}`
- `{"type":"textValidated","result":<ValidationResult>}`
- `{"type":"commandFailed","failure":{"command":<ClientCommand>,"message":<text>}}`

Validation results:

- `{"type":"validationSucceeded","text":<source>}`
- `{"type":"validationFailed","text":<source>,"message":<message>}`

Backend session snapshots use the derived Aeson field names from
`Riptide.Session`: `sessionSlotCapacity`, `sessionTracks`,
`sessionDefinitions`, `trackId`, `trackName`, `trackSlot`, `trackTexts`,
`trackActiveText`, `trackSelectedText`, `trackTextId`, `trackTextSource`,
`blockId`, `blockName`, `blockCode`, and `blockApplied`.

## Success Criteria

- The frontend builds in Nix and with the frontend dev shell.
- The existing pure reducer/import/export/playhead tests stay green.
- New protocol/client tests prove the JSON command and event shapes.
- With `riptide serve`, the frontend connects to `/ws`, validates through the
  backend, and launch/stop/score automation send backend commands.
- Without a backend, the static frontend loads, shows disconnected/fallback
  state, and the mock launch/score behavior still works.

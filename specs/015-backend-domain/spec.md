# Feature Specification: Backend Domain And Stores

**Issue**: #15
**Branch**: `feat/backend-domain`
**Created**: 2026-07-04
**Status**: Draft

## User Story

A performer can maintain a server-owned set of Tidal track variations and shared
definition blocks. The backend owns the persistent state, assigns hidden Tidal
slots for playback, and exposes pure reducers that preserve the launch-grid
invariants before later tickets attach websocket and audio effects.

## Functional Requirements

- **FR-001**: The backend domain model represents tracks, track texts/cells,
  selected text, active text, and definition blocks.
- **FR-002**: A track enforces at most one active text at a time. Activating one
  text on a track silences any previous active text on that track.
- **FR-003**: Each track has exactly one hidden slot drawn from a bounded pool
  `d1` through `dN`; slots are unique among live tracks and recycled when a track
  is removed.
- **FR-004**: Reducers are pure functions over session state. They cover
  activating, silencing, editing, saving, adding, removing, and selecting track
  texts, plus adding, editing, applying, and removing definition blocks.
- **FR-005**: Definition blocks keep an editor buffer and an applied value, so
  unapplied changes are visible in state and applying a block copies the buffer
  into the applied value.
- **FR-006**: Tracks and definitions persist in two separate JSON stores under a
  caller-provided state directory.
- **FR-007**: Store loading loads definitions before tracks and returns one
  session state assembled from both stores.
- **FR-008**: Timing and transport remain outside the backend domain for this
  ticket. `TOTAL_BARS` or score shape may be represented, but no reducer should
  implement client playhead behavior.

## Success Criteria

- Domain and store behavior is available from new `Riptide.*` backend modules
  without changing `Riptide.Eval`.
- Unit tests include Hspec examples and QuickCheck properties with standalone
  generators, not `Arbitrary` instances.
- Properties cover the active-text invariant, slot uniqueness, and store
  round-trip behavior.
- `nix build .#riptide` and the backend unit suite pass.

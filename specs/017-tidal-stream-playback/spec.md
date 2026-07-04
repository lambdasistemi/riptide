# Issue 17 Spec: Tidal Stream Playback

## P1 User Story

As a remote riptide operator, I can configure the backend to send Tidal
patterns to my SuperDirt OSC endpoint, activate one active text per hidden
track slot, and silence that slot without the backend or tests requiring a
local audio server.

## Functional Requirements

- FR-001: The backend exposes a playback boundary that can activate a track's
  active text by interpreting it with the session's applied definitions.
- FR-002: Activation sends the interpreted `ControlPattern` to the track's
  hidden `Slot` using Tidal's `streamReplace` semantics.
- FR-003: Silence clears playback for the track's hidden `Slot` using Tidal's
  `streamSilence` or equivalent silence semantics.
- FR-004: A real Tidal stream can be started with a configurable SuperDirt OSC
  host and port. Default values are `127.0.0.1` and `57120`, but the host is
  not hardcoded and can be set to a remote Tailscale address.
- FR-005: When no target is configured, playback construction succeeds with a
  dry/no-op backend that records or logs intended operations instead of sending
  OSC.
- FR-006: Unit tests verify activation, silence, and unconfigured dry behavior
  without requiring SuperDirt, audio, or a live OSC listener.
- FR-007: Existing `Riptide.Session` reducers remain read-only and continue to
  own the one-active-text-per-track invariant.

## Acceptance Criteria

- Activating a session track with active text causes exactly one replace
  operation for the track's slot after successful interpretation.
- Applied definition blocks are passed to `Riptide.Eval` during activation.
- Silencing a track causes exactly one silence operation for the track's slot.
- Missing active track/text or interpreter failure returns a recoverable error
  and does not crash.
- Real playback configuration can produce a Tidal backend targeting arbitrary
  host/port values, including a Tailscale host.
- `./gate.sh` passes locally.
- The draft PR CI reports 4/4 successful jobs before completion.

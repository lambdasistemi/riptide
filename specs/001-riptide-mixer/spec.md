# Feature Specification: riptide — Live Tidal Track Mixer (Epic)

**Feature Branch**: `001-riptide-mixer`

**Created**: 2026-07-03

**Status**: Draft

**Input**: A graphical mixer for TidalCycles: a database of tracks switched on
and off from a score grid, whose parameters are shaped by directly manipulating
the numbers and mini-notation patterns in each track's text. Active tracks play
in Tidal; inactive tracks are edited as prepared text. This is the umbrella
epic covering v1.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Manage a track database (Priority: P1)

A performer maintains a collection of named Tidal tracks. Each track is a piece
of Tidal source text (e.g. `s "arpy*4" # accelerate 0.01 # n "2"`) with a name
and an assigned output slot (`d1`…`dN`). They can add a track, edit its raw
text, rename it, remove it, and the collection persists across restarts.

**Why this priority**: Nothing else exists without a store of tracks to mix.
This is the foundational slice and is independently useful as a Tidal snippet
manager even before playback.

**Independent Test**: Create several tracks with raw text, restart the app, and
confirm they reload intact and are individually editable.

**Acceptance Scenarios**:

1. **Given** an empty database, **When** the performer adds a track with a name
   and Tidal text, **Then** it appears in the collection and is persisted.
2. **Given** a saved track, **When** the app restarts, **Then** the track
   reloads with identical name, slot, and text.
3. **Given** a track, **When** the performer edits its raw text and saves,
   **Then** the new text replaces the old and persists.

---

### User Story 2 - Switch tracks on/off from a score grid (Priority: P1)

The performer sees all tracks as cells in a score grid and clicks a cell to
switch that track on or off. Switching on sends the track's current text to
Tidal to play on its slot; switching off silences that slot. A track is only
allowed to switch on if its text validates as a Tidal pattern; invalid tracks
are visibly marked and cannot be activated. Inactive tracks show they are in
"prepared text" state.

**Why this priority**: This is the core mixing act — the reason the app exists.
Combined with US1 it is the MVP: a working live mixer over raw-text tracks.

**Independent Test**: With SuperDirt running, toggle a valid track on and hear
it play on its slot; toggle off and hear it stop. Toggle an invalid track and
confirm it is blocked with an error shown.

**Acceptance Scenarios**:

1. **Given** a valid inactive track, **When** the performer clicks its cell,
   **Then** it activates on its slot and the cell shows an active state.
2. **Given** an active track, **When** the performer clicks its cell, **Then**
   its slot is silenced and the cell shows an inactive state.
3. **Given** a track whose text does not type-check as a pattern, **When** the
   performer tries to activate it, **Then** activation is refused and the
   validation error is shown.
4. **Given** an active track whose text is edited to a still-valid pattern,
   **When** the performer re-activates/updates it, **Then** the running slot
   reflects the new text.

---

### User Story 3 - Scrub numeric parameters in the track text (Priority: P2)

Every numeric value in a track's text is a live widget. The performer points at
a number (`accelerate 0.01`, or the `2` inside `n "2"`) and turns the mouse
wheel to nudge it up or down; the step follows the literal's format (`0.01`
scrubs by `0.01`, an integer by `1`). Clicking a number opens a slider with a
sensible range for that control. Scrubbing rewrites only that number in the
text and leaves the rest of the track untouched.

**Why this priority**: This is the "intelligence" that makes it a shaping tool
rather than a text box. It builds on US1/US2 but is a distinct, independently
demonstrable slice.

**Independent Test**: Point at a number in a track, wheel-scrub it, and confirm
the text updates in place with correct step, the rest of the track unchanged,
and (for a known control) a click opens a ranged slider.

**Acceptance Scenarios**:

1. **Given** a track containing `accelerate 0.01`, **When** the performer wheels
   up on `0.01`, **Then** the text becomes `accelerate 0.02` and nothing else
   changes.
2. **Given** a number inside a pattern string such as `n "2"`, **When** the
   performer scrubs it, **Then** only that number inside the string changes.
3. **Given** a recognized control, **When** the performer clicks its number,
   **Then** a slider bounded by that control's sensible range appears.
4. **Given** any scrub or slider edit, **When** the regenerated text is
   re-parsed, **Then** it yields the same structure (round-trip fidelity).

---

### User Story 4 - Edit mini-notation patterns visually (Priority: P3)

The performer edits a track's mini-notation pattern (e.g. `"bd [sn cp] hh*2"`)
as a visual layout of nested time-boxes tiling a cycle, rather than as a raw
string. They can add/remove steps, subdivide a step, set a step's sample/name,
scrub speed (`*`/`/`) and euclid `(k,n)` parameters, and toggle euclid slots —
all with the mouse. Constructs the editor does not model (alternation `<>`,
polymeter `{}`, arbitrary surrounding Haskell) remain editable as opaque text.

**Why this priority**: The richest and most exploratory piece; valuable but not
required for a usable mixer. It sits on top of the same parser/AST as US3.

**Independent Test**: Open a track with a sequence pattern, subdivide and rename
boxes and scrub a `*n`, and confirm the regenerated mini-notation string is
correct and plays as expected; confirm an unmodeled construct falls back to a
text node without error.

**Acceptance Scenarios**:

1. **Given** `"bd sn hh"`, **When** the performer subdivides the middle box into
   two, **Then** the string becomes `"bd [sn ...] hh"` with the new structure.
2. **Given** a euclid pattern `bd(3,8)`, **When** the performer toggles a slot
   or scrubs `k`/`n`, **Then** the notation updates accordingly.
3. **Given** a pattern containing an alternation `<a b>`, **When** it is opened,
   **Then** that portion is shown as an editable opaque text node, not mangled.

### Edge Cases

- A track's text is not valid Tidal at all → it is stored and editable, shown
  as invalid, and cannot be activated (US2), but never lost (Principle IV).
- Text contains constructs the parser does not model → those become opaque text
  nodes; surrounding recognized parts still project to widgets.
- SuperDirt / audio backend is not running → activation attempts surface a clear
  connection error rather than failing silently.
- Two tracks assigned to the same slot → the later activation replaces the
  earlier on that slot (last-write-wins per slot).
- Scrubbing a number to the edge of a control's sensible range → clamped, with
  the raw text still free to hold any typed value.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST let the performer create, rename, edit (raw text),
  and remove tracks, each with a name and an output slot.
- **FR-002**: System MUST persist the track database and reload it identically
  on restart.
- **FR-003**: System MUST present all tracks in a score grid and let the
  performer toggle each track on/off by clicking its cell.
- **FR-004**: System MUST validate a track's text as a Tidal pattern before
  activation, produce no sound while validating, and refuse activation of
  invalid tracks while showing the error.
- **FR-005**: System MUST activate a track by playing its current text on its
  slot and deactivate by silencing that slot.
- **FR-006**: System MUST parse a track's text into a structure that locates
  every numeric value and every mini-notation pattern, and MUST regenerate text
  from that structure without altering unrelated parts.
- **FR-007**: System MUST render each numeric value as a widget supporting
  mouse-wheel scrubbing (step inferred from the literal) and click-to-slider
  (range inferred from the control), including numbers inside pattern strings.
- **FR-008**: System MUST render supported mini-notation patterns as an editable
  visual time-box layout and regenerate valid notation from edits.
- **FR-009**: System MUST represent any text it cannot model as an opaque,
  editable node that remains valid, sendable, and validatable.
- **FR-010**: System MUST guarantee round-trip fidelity: re-parsing regenerated
  text yields the same structure for all supported constructs.
- **FR-011**: System MUST keep a running track's slot in sync when its text is
  updated and re-activated.

### Key Entities *(include if feature involves data)*

- **Track**: A named unit of the mix — name, output slot (`d1`…`dN`), Tidal
  source text, and derived active/valid state. The source text is authoritative.
- **Track Database**: The persisted collection of tracks; the app's document.
- **Track AST**: The parsed structure of a track's text — recognized controls
  with numeric arguments, mini-notation patterns (as nested time-boxes), and
  opaque text nodes. Purely derived from and rendered back to the text.
- **Numeric Widget**: A located number in the text with an inferred scrub step
  and, for recognized controls, a sensible slider range.
- **Slot / Stream Channel**: A Tidal output channel (`dN`) a track plays on;
  at most one active track per slot.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A performer can go from empty database to a valid track playing in
  Tidal in under 1 minute, using only the GUI.
- **SC-002**: Toggling a track on/off from the grid takes effect within one
  audible cycle and never produces a stuck/orphaned voice on its slot.
- **SC-003**: Scrubbing any number changes only that number; a property test
  over generated tracks shows 100% round-trip fidelity for supported constructs.
- **SC-004**: 100% of tracks — including ones the editor cannot fully parse —
  are stored, reloaded, and editable without data loss.
- **SC-005**: An invalid track is never activated, and its validation error is
  shown to the performer.

## Assumptions

- A SuperDirt / SuperCollider audio backend is available and reachable for
  playback; riptide connects to it via the compiled-in Tidal stream.
- Live modification of *running* patterns via OSC control buses is **out of v1
  scope**; in v1, sliders shape the prepared text, and changes take effect on
  (re)activation.
- Visual editing of alternation `<>` and polymeter `{}`, and any
  timeline/arrangement view, are **out of v1 scope** (shown as text for now).
- Single-user, single-machine, local use; no multi-user collaboration or
  network sharing in v1.
- The set of recognized controls and their sensible ranges is a curated,
  extensible table; unknown controls still scrub with a generic step/range.

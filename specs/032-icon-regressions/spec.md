# Specification: Icon Regression And Action Fixes

## User Story

When a performer uses the launch grid after the icon refactor, icon buttons must
be visible and actionable. Cell grip/select controls, launch/stop, delete
confirmation, and the song rail must remain usable in the served app.

## Functional Requirements

- Cell header grip and select controls show non-empty visible SVG glyphs.
- A launchable active cell remains enabled so clicking it stops/un-arms the
  cell.
- Two-step danger buttons arm on first click and confirm on the second for cell,
  track, song, toolbox, and block delete flows.
- The song rail lays out song names and row actions without wrapping into a
  crowded cluster.
- The headless render smoke fails if icon buttons contain empty/invisible glyphs
  or if launch/stop interaction is broken.

## Success Criteria

- Browser verification shows visible grip/select glyphs in cell headers.
- Browser verification shows a launchable cell toggles active and toggles back.
- Browser verification shows at least one delete button changes to its confirm
  state after the first click.
- `./gate.sh` passes and includes interaction/visibility checks.

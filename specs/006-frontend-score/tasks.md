# Issue 6 Tasks

## Slice 1 — Score Timeline And Playhead
- [x] T006-S1 Add `frontend/src/Riptide/View/Score.purs` with lanes, labels, bars, loop controls, view toggle, and Score empty state.
- [x] T006-S1 Add the playhead rAF effect module/FFI and wire it through `Riptide.App` so playback runs only while `playing`.
- [x] T006-S1 Replace the placeholder in `Riptide.View.Song` with the real Score region.
- [x] T006-S1 Wire painting, loop controls, transport, and playhead actions to existing pure reducer helpers.
- [x] T006-S1 Add Score styles to `frontend/dist/index.html`.
- [x] T006-S1 Prove with `./gate.sh` and commit `feat(frontend): add score timeline`.

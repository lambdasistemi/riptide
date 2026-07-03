# Issue 6 Plan

## Stack
- PureScript + Halogen.
- Reuse pure core modules from ticket 4: `Riptide.Model`, `Riptide.Reducer`, `Riptide.Helpers`, and `Riptide.Validation`.
- Plain CSS in `frontend/dist/index.html`, matching the existing dark OKLCH view layer.
- JavaScript FFI only for `requestAnimationFrame` / `cancelAnimationFrame` if Halogen/browser packages do not already expose a simpler project-local path.

## Slice 1 — Score Timeline And Playhead
- Add `Riptide.View.Score` for the full Score panel and lane rendering.
- Add a small playhead effect module/FFI and wire it from `Riptide.App`.
- Replace the Song page placeholder with `Score.render`.
- Extend app actions for painting, transport, loop controls, and view toggle.
- Add CSS for lanes, bar cells, loop markers, fixed/scroll playhead modes, empty scheduling hint, and responsive score layout.
- Proof: frontend build, existing core tests, and a headless/browser smoke note if available.

## Boundaries
- Do not reimplement `applyAutomation`, paint reducers, or loop clamp reducers.
- Do not edit the Definitions page, DnD/import/export effects, backend code, or backend flake outputs.
- Keep any dependency additions additive and justified; prefer project-local FFI over new packages if practical.

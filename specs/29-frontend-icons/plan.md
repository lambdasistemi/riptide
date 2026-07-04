# Plan

## Stack and constraints

- PureScript Halogen frontend under `frontend/src/Riptide/View`.
- Static CSS shell in `frontend/dist/index.html`.
- No dependency changes. Use the already-pinned Halogen/SVG packages or plain
  Halogen attributes to emit inline SVG.
- Behavior-changing files outside `View/*.purs` are forbidden.

## Slice 1: icon button skin

One vertical commit updates the UI skin:

- Add a shared icon helper under `Riptide.View` so SVG shape definitions are
  centralized and every module uses the same line-icon grammar.
- Replace command button text in `Shell`, `Song`, `Definitions`, and `Score`
  with icon contents plus `title` attributes.
- Keep labels where they are content: tabs, song/toolbox names, track and cell
  status, slider labels, score readouts, badges, and empty-state copy.
- Add CSS for `.rt-icon-button` and related compact/primary/danger states in
  `frontend/dist/index.html`, including stable target sizes and tooltip-friendly
  layout.
- Run formatting, `nix build .#frontend`, and the repo gate.

## Verification

- Focused build: `nix build .#frontend`.
- Full gate: `./gate.sh`.
- Manual review of the final diff checks that only owned UI files, specs, and
  `gate.sh` changed.

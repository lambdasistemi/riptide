# Issue 14 — Frontend Polish Plan

## Scope

Skin-only frontend polish for the existing Halogen app. The implementation should be concentrated in `frontend/dist/index.html`; `frontend/src/Riptide/View/*.purs` is reserved for class-only hook additions if the stylesheet cannot target an existing element.

## Reference

- Prototype source: `frontend/design/Riptide.dc.html`
- Shipped shell: `frontend/dist/index.html`
- Existing views: `frontend/src/Riptide/View/Shell.purs`, `Song.purs`, `Definitions.purs`, `Score.purs`

## Slice 1 — Designer CSS + Fonts

One bisect-safe commit:

- Add prototype Google Fonts link to the static shell.
- Replace the current hand-approximated stylesheet with a close port of the prototype's visual language mapped to current `rt-*` classes.
- Preserve behavior and markup structure.
- Verify with `./gate.sh`.

## Verification

`./gate.sh` runs:

1. `nix build .#frontend`
2. `nix develop -c just unit`

Optional visual proof: serve `frontend/dist` and capture a headless browser screenshot before/after implementation.

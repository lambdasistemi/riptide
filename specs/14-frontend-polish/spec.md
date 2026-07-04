# Issue 14 — Frontend Polish

## P1 User Story

As a riptide user, I want the shipped Song, Definitions, and Score views to match the designer prototype's visual system so the app feels like the intended live-coding instrument rather than an approximate hand-styled shell.

## Requirements

- Adopt the prototype font link from `frontend/design/Riptide.dc.html` in `frontend/dist/index.html`.
- Use Space Grotesk for UI chrome and JetBrains Mono for code-oriented text, textareas, and cell content.
- Port the prototype's dark OKLCH palette, density, spacing, radii, scrollbar, range input, accent glow, idle/active/error states, and shadow treatment onto existing `rt-*` classes.
- Keep the change skin-only: no component logic, state, behavior, or markup structure changes.
- Preserve existing class names and style hooks. PureScript view edits are allowed only for class attributes if a CSS hook is strictly required.

## Success Criteria

- `frontend/dist/index.html` includes the same Google Fonts link used by the prototype.
- The shipped app visually tracks the prototype across the top bar, rails, lists, launch grid, definition cards, and score/timeline surfaces.
- `nix build .#frontend` succeeds.
- The core Haskell test suite continues to pass via `nix develop -c just unit`.

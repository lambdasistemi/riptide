# Issue 34: explicit armed-delete cancel

## P1 Story
A user who accidentally arms a destructive delete can back out immediately without waiting for the timeout and without risking a second click deleting data.

## Scope
- Frontend only.
- Applies to every gated delete: song, toolbox, track, cell, and block.
- Fold in the added CSS pass: icon glyphs must be visually centered inside their button boxes.

## Functional Requirements
- When `confirm` is set for a delete key, the UI shows a cancel affordance next to that item's "Confirm delete" action.
- Activating cancel clears `confirm` immediately and does not delete the item.
- Pressing `Esc` clears an armed confirmation.
- Clicking elsewhere clears an armed confirmation.
- The existing 2800ms auto-cancel remains as a fallback.
- Confirming by clicking the armed delete button still deletes the target.
- Icon buttons, drag grips, select buttons, transport buttons, rail buttons, top-bar buttons, and add-cell buttons center their SVG glyphs in a stable box.

## Success Criteria
- Unit coverage proves reducer-level disarm if a pure reducer function is added.
- Browser smoke proves arm -> cancel keeps the item and clears confirm UI, and arm -> confirm still deletes.
- Browser smoke includes practical evidence that icon glyphs are visible and centered in their button boxes.
- `./gate.sh` passes.

# Issue 5 Plan

## Stack
- PureScript + Halogen.
- Reuse pure core modules: `Riptide.Model`, `Riptide.Reducer`, `Riptide.Helpers`, `Riptide.Validation`, `Riptide.Action`.
- Plain CSS in `frontend/dist/index.html`, matching the prototype's dark OKLCH visual language.

## Slice 1 — App Foundation And Seed
- Replace the placeholder app with a Halogen root component.
- Add `Riptide.App` and view helpers/modules as needed.
- Implement initial seed data faithfully from §11.
- Implement shell navigation, engine/hush controls, id minting helpers, and placeholder page shells.
- Proof: build and core tests.

## Slice 2 — Song Page
- Implement song switcher rail and song management.
- Implement launch grid rows, track gutter controls, cell interactions, and two-step deletes.
- Cover §10 cell and track states.
- Add a clearly marked Score placeholder, with no timeline behavior.
- Proof: build, core tests, and smoke notes.

## Slice 3 — Definitions Page
- Implement toolbox rail and toolbox management.
- Implement block list editing, apply/apply-all, validity/unsaved/applied states, cascade warnings, and scope chip warnings.
- Polish empty states and responsive layout for both pages.
- Proof: full gate and browser smoke.

## Boundaries
- Do not edit pure-core behavior modules unless a ticket-level blocker is escalated.
- Do not implement the Score timeline, drag/drop, file import/export effects, backend, or flake backend outputs.
- File import/export buttons may exist only as inert/toast placeholders; blob/file plumbing belongs to ticket #7.

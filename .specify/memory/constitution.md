# riptide Constitution

riptide is a graphical mixer for live [TidalCycles](https://tidalcycles.org)
performance: a database of tracks toggled on/off from a score grid, whose
parameters are shaped by directly manipulating the numbers and mini-notation
patterns in each track's text.

## Core Principles

### I. Text Is the Source of Truth

A track's Tidal source text is the single authoritative representation. Every
interactive widget — scrubbable numbers, sliders, the visual mini-notation
editor — is a **bidirectional projection** of that text: text → AST → widgets,
and every edit flows back AST → text. No widget holds state the text does not.
The user can always drop to raw text and lose nothing.

### II. Pure Core, Impure Shell

The parser, AST, round-trip renderer, and all text/pattern transformations are
**pure functions** with no IO. The impure shell — the Tidal stream, the `hint`
interpreter, the track store, the websocket server — calls the pure core but
never embeds domain logic. This boundary is non-negotiable: if a transformation
needs IO, the design is wrong.

### III. Round-Trip Fidelity (Correctness Gate)

The central correctness property: **editing one widget never corrupts the rest
of the track, and parsing regenerated text yields the same AST.** Formally, for
supported constructs `parse (render ast) ≡ ast`, and `render (parse t)`
preserves `t` up to normalization. Lean proofs are **not** used on this project;
these invariants are guarded by **QuickCheck** properties over generated ASTs
and track texts. A construct is not "supported" until its round-trip property
holds.

### IV. Graceful Fallback

The editor models the mini-notation and recognized Tidal controls it
understands; **everything else degrades to an opaque, editable text node** that
is still valid, still sendable, still validatable — just not visually
structured. The app must never refuse or mangle a track because it cannot fully
parse it. Coverage grows over time; unparsed input is a display limitation, not
an error.

### V. Validate Before Sound

A track is only activated after it type-checks as a Tidal `ControlPattern` via
the backend `hint` interpreter (`:t`-style, producing no sound). Local parsing
gives instant structural feedback; the `hint` typecheck is the authoritative
gate. A track that fails typecheck is visibly marked and cannot be toggled on.
Only explicit activation produces sound.

## Technical Constraints

- **Backend**: Haskell. Links the `tidal` library for playback
  (`Sound.Tidal.Stream`) and `hint` for runtime validation/interpretation of
  track text. Owns the track database and exposes a websocket API. No GHCi
  subprocess, no stdin piping — Tidal is compiled in.
- **Frontend**: PureScript + Halogen. Renders the score grid and the
  text-projection editor. Communicates with the backend over websocket.
- **Nix-first**: `flake.nix` provides every build tool; CI and local dev use the
  same `nix develop` shell. No `pip`/`curl | sh`/ad-hoc setup steps.
- **Deferred to later versions (explicitly out of v1 scope)**: live control-bus
  OSC sliders that modify *running* patterns; visual editing of alternation
  `<>` and polymeter `{}` (shown as text in v1); timeline/arrangement view.

## Development Workflow

- **Speckit at epic granularity** — this project uses Spec-Driven Development at
  the **epic level**: broad specs and plans per epic, not a spec per trivial
  change. Every epic has `spec.md` → `plan.md` → `tasks.md` before
  implementation. The constitution gates all planning.
- **PRs only, never push to main.** Linear history (rebase merge). Conventional
  Commits. Every PR labeled and assigned.
- **CI gates**: build, unit tests (incl. round-trip QuickCheck properties),
  fourmolu format-check, hlint, cabal-check — all green before merge, on the
  self-hosted `nixos` runner.
- **Tests run locally first** (`just ci`) before pushing.

## Governance

This constitution supersedes ad-hoc practice. Amendments are made by PR editing
this file, with a version bump and rationale. Complexity that violates a
principle must be justified in the epic's `plan.md` or rejected. The pure/impure
boundary (II) and round-trip fidelity (III) are the load-bearing invariants;
changes that weaken them require explicit sign-off.

**Version**: 1.0.0 | **Ratified**: 2026-07-03 | **Last Amended**: 2026-07-03

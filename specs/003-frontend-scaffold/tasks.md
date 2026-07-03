# Tasks

## Slice 1: frontend project skeleton

- [X] T003-S1 Create the frontend PureScript app files and static shell.
- [X] T003-S1 Commit `spago.lock`, `package-lock.json`, and copied design references.
- [X] T003-S1 Prove the skeleton with a focused frontend build or documented pre-Nix smoke.

## Slice 2: Nix frontend package and shell

- [ ] T003-S2 Add PureScript Nix inputs and frontend package output additively.
- [ ] T003-S2 Add the frontend dev shell with the required tools.
- [ ] T003-S2 Prove `nix build .#frontend` produces `index.html` and `index.js`.

## Slice 3: frontend CI

- [ ] T003-S3 Add the frontend CI job without changing existing backend jobs.
- [ ] T003-S3 Prove `nix develop .#frontend -c just lint` succeeds.
- [ ] T003-S3 Run the full ticket gate.

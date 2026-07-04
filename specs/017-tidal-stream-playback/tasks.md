# Issue 17 Tasks: Tidal Stream Playback

## Slice A: Dry Playback Wiring

- [X] T017-S1 Add `Riptide.Playback` with playback backend operations and
  activation/silence orchestration over `Riptide.Session`.
- [X] T017-S1 Add a dry recording backend for tests and unconfigured runtime
  behavior.
- [X] T017-S1 Add unit tests proving activate sends the interpreted active text
  to the track slot, silence clears the track slot, and missing inputs do not
  crash.
- [X] T017-S1 Wire the new module/test into `riptide.cabal` and `test/Spec.hs`.
- [X] T017-S1 Run focused tests and `./gate.sh`, then commit one bisect-safe
  slice with `Tasks: T017-S1`.

## Slice B: Real Tidal Backend And Config

- [ ] T017-S2 Add configurable SuperDirt target parsing with
  `RIPTIDE_SUPERDIRT_HOST` and `RIPTIDE_SUPERDIRT_PORT`.
- [ ] T017-S2 Add real Tidal backend construction using
  `superdirtTarget{oAddress = host, oPort = port}`, `startTidal`,
  `streamReplace`, and `streamSilence`.
- [ ] T017-S2 Add tests proving unconfigured mode selects dry playback, invalid
  config returns an error, and remote host/port values are preserved.
- [ ] T017-S2 Run focused tests and `./gate.sh`, then commit one bisect-safe
  slice with `Tasks: T017-S2`.

## Finalization

- [ ] T017-F1 Push branch and open/update a draft PR against `main`.
- [ ] T017-F1 Verify local `./gate.sh` and PR CI are both green.
- [ ] T017-F1 Remove `gate.sh` in the final ready-for-review commit if the
  ticket workflow requires dropping the temporary gate sentinel.

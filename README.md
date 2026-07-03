# riptide

Live [TidalCycles](https://tidalcycles.org) track mixer.

A graphical application to manage a database of Tidal tracks: switch them on and
off from a score grid, and shape their parameters by directly manipulating the
numbers and patterns in the track text — mouse-wheel to scrub a value, click for
a ranged slider, and edit mini-notation patterns as visual time-boxes.

- **Backend** (Haskell) — links the `tidal` library for playback and `hint` to
  validate/interpret track text as `ControlPattern` values. Owns the track DB.
- **Frontend** (PureScript / Halogen) — score grid, scrubbable numbers, and the
  visual mini-notation editor.

The track text is the source of truth; every widget is a bidirectional
projection of it.

## Development

```
nix develop
just            # list recipes
```

## License

BSD-3-Clause

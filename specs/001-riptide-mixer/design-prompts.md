# riptide — Interface Design Prompts

Prompts for an interface-design tool (generates the visual UI). They describe
the *screens*, not the backend. riptide has **two top-level pages** — **Song**
and **Definitions** — inside one app shell.

- **Song page** = the **launch grid** (play a text live, at most one active text
  per track) **+ the Score timeline** (pre-paint when tracks go on/off; a
  playhead auto-drives the same launching). Same tracks, two ways to trigger.
- **Definitions page** = the shared `let` scope (the prelude every snippet uses),
  stored in a separate DB and reusable across songs.

The `dN $` slot management is always hidden — the user edits only pattern bodies.
Version scope throughout: plain text editing + start/stop only. No knobs, no
scrubbable numbers, no visual pattern editor, no waveforms/curves.

---

## 1. App shell (the "prompter")

```
Design riptide, a desktop app for live music performance with TidalCycles.
Organized as two pages the performer switches between: Song and Definitions.
Persistent navigation between them; same dark, focused, monospace, performance
aesthetic across both; a global engine/connection indicator and a global "Hush"
(panic-stop) reachable from anywhere.
```

---

## 2. Song page — launch grid  *(already designed; do not redesign)*

The grid is final: rows = tracks (lanes), cells = texts (short Tidal snippets).
Start/stop texts live; at most one active text per track; active cell glows,
others in the row idle; launching a different cell replaces the active one;
clicking the active cell silences the row. Cells show validity (invalid = red,
launch disabled).

**Song management** wraps the grid: a song = one whole grid (its tracks + texts);
riptide holds many songs; a song switcher with new · open · rename · duplicate ·
delete, current song named. Switching songs swaps the grid content; the grid
design itself does not change.

---

## 3. Song page — Score timeline  *(added to the Song page, not a new page)*

```
Extend the existing Song page to include a Score timeline as part of it. Do NOT
create a new top-level page, and do NOT redesign the existing launch grid — it
stays exactly as designed. The Score is a second region on the same Song page,
sharing the same tracks.

The Score: a moving timeline that automates the same track on/off the launch grid
does by hand. Rows = the same tracks (aligned with the grid); columns = time
divisions (bars). A visible playhead sweeps forward. The performer paints cells
ahead of the playhead to schedule a track ON for those bars; when the playhead
enters a painted region the track switches on automatically (activating that
track's currently selected text), and off when it exits. A contiguous run of
painted cells = one on-duration (five cells = five bars, then off). Cells can be
painted/erased ahead of the moving playhead.

Layout relationship: place the Score so its track rows read as the same tracks as
the launch grid (timeline lane area beneath/beside the grid, rows aligned). A
track lit "on-now" by the score shows as active in the grid too — grid launching
and score automation drive the same track state.

Scroll vs fixed is a VIEW the user toggles, not two different scores: the score is
one timeline, and the user chooses either (a) the playhead stays fixed and the
score scrolls under it, or (b) the score stays fixed and the playhead travels
across it. Same underlying score, two views — provide the toggle.

States: cell empty · scheduled/painted · playing-now; track row idle ·
scheduled-ahead · on-now; transport play/stop for the playhead + current bar
position.

Deliver: the Song page showing the existing grid PLUS the aligned Score timeline,
a populated example (tracks with painted regions of varying length, one playing
under the playhead), both view modes, and the empty state.
```

---

## 4. Definitions page — the `let` scope

```
Design the Definitions page: a manager for the shared code every grid snippet
relies on — the session's prelude of `let` definitions (helper functions, named
sub-patterns, custom control combos, tempo). Everything here is in scope for
every text on the Song grid. Stored separately from songs; saveable/loadable as a
reusable "toolbox" carried between sessions.

Layout: a vertical list of definition blocks. Each block has an editable
name/label, an editable monospace code area holding one or more `let` bindings, a
validity state (valid vs invalid with inline error), an applied-vs-unsaved
indicator, and an Apply action to (re)evaluate it into the live session. Blocks
can be added, removed, renamed, reordered (order can matter — later blocks may use
earlier ones). Header: Apply all, engine indicator, import/export of the whole
set.

Critical behavior: applying an invalid block, or one that breaks others, cascades
— because these definitions are shared, surface how many grid snippets now fail
("N snippets now fail to compile"). Distinguish saved/applied from
edited-but-not-applied so the performer knows the live session may differ from
the screen.

Toolbox management: a toolbox = one whole set of definition blocks; switcher with
new · open · rename · duplicate · delete · import/export, current toolbox
indicated and visible from the Song page so the performer knows which shared scope
is live.

States: block empty · valid-applied · valid-with-unsaved-edits · invalid ·
editing; page engine connected/disconnected, toolbox saved/modified.

Feel: same dark aesthetic; calmer and more text-editor-like than the grid — this
is where you prepare, not perform. Generous editing space, clear per-block
boundaries.

Deliver: the page with the block states above, an example with ~3–4 blocks (one
invalid, showing the cascade warning), and the empty state.
```

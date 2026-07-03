# riptide — Behavior Spec (framework-agnostic)

This is the source-of-truth behavior spec for the riptide UI, extracted from the
HTML/JS prototype in `Riptide.dc.html`. It describes **state, derived values,
actions, and states** with no dependency on the prototype's rendering runtime.
Translate this into your PureScript UI layer (Halogen / react-basic / etc.). The
prototype file remains the reference for exact visual styling; this doc is the
reference for *logic*.

Everything here is pure UI/state. There is **no real audio engine** — the
"engine" is a boolean the performer toggles, and "playing" a cell only sets
state. Wiring to SuperCollider/Tidal is out of scope for this spec.

---

## 1. Domain model

Three nested collections plus transient UI state.

```
App
 ├─ songs        : Song[]          -- each Song is one whole launch grid + score
 ├─ currentSongId
 ├─ toolboxes    : Toolbox[]       -- reusable shared `let` scopes ("toolboxes")
 ├─ currentToolboxId
 └─ (transient UI + transport state, see §2)

Song    = { id, name, tracks : Track[] }
Track   = { id, name, hue:Int, vol:Int, flt:Int, dly:Int,
            active   : CellId | null,   -- the cell currently sounding (0/1 per track)
            selected : CellId | null,   -- the "armed" variation the Score schedules
            score    : Bool[16],        -- one on/off flag per bar
            cells    : Cell[] }
Cell    = { id, code : String }        -- a short Tidal snippet ("text")
Toolbox = { id, name, blocks : Block[] }
Block   = { id, name : String, code : String, applied : String }
```

Notes:
- `hue` is an integer 0–360 used to derive the track's accent color (see §9).
- `vol`, `flt`, `dly` are integers 0–100 (volume/gain, low-pass cutoff, delay send).
- `score` is a fixed-length array of 16 booleans (16 bars). Painted = scheduled ON.
- A Track enforces **at most one active cell** (`active` is a single id or null).
- `selected` is independent of `active`: it's which variation the Score/relaunch
  will fire. See §6.
- A Block's `code` is the live editor buffer; `applied` is the last value pushed
  to the "live scope". `code !== applied` ⇒ **unsaved**.

### IDs
All ids are opaque strings. The prototype generates them as a short prefix + 6
random base36 chars: songs `s…`, tracks `t…`, cells `c…`, toolboxes `tb…`,
blocks `b…`. Any unique-id scheme is fine; ids must be stable across renders and
regenerated on duplicate/import (never reuse a source id).

---

## 2. Full state shape

```
{ page            : "song" | "defs"          -- which top-level page is shown
, engine          : Bool                       -- audio-engine connection indicator
, songs           : Song[]
, currentSongId   : SongId | null
, toolboxes       : Toolbox[]
, currentToolboxId: ToolboxId | null

-- transport / score
, playing         : Bool                        -- playhead running
, playhead        : Number                      -- float bar position, 0..16
, loopStart       : Int                          -- 0..15  (inclusive bar index)
, loopEnd         : Int                          -- 1..16  (exclusive)
, loopOn          : Bool                          -- false = ignore limiters

-- transient UI (may be ephemeral / not persisted)
, hoverCell       : CellId | null                -- cell under mouse (grid)
, focusCell       : CellId | null                -- focused code textarea (grid)
, confirm         : String | null                -- armed two-step delete key (see §7)
, editing         : { type:"song"|"tbx", id } | null   -- inline rename target
, drag            : DragState | null             -- see §8
, over            : DropTarget | null            -- see §8
, toast           : String | null                -- transient status message
, songRailOpen    : Bool
, toolboxRailOpen : Bool
, scoreHeight     : Int                           -- px height of the score panel
, resizing        : Bool                          -- grid/score divider being dragged
}
```

`TOTAL_BARS = 16` is a constant throughout.

### Seed / initial state
`page="song"`, `engine=true`, `playing=true`, `playhead=2.35`, `loopStart=0`,
`loopEnd=12`, `loopOn=true`, `scoreHeight=300`, both rails open. Two seed songs
("midnight set" with 5 tracks, "warm-up" with 2 tracks and empty scores), two
seed toolboxes ("live set" 4 blocks incl. one invalid, "ambient rig" 2 blocks).
Seed content is illustrative; see §11 for the exact seed used by the prototype.

---

## 3. Derived values (compute on read, don't store)

- `currentSong`  = songs.find(id == currentSongId) | null
- `gridTracks`   = currentSong?.tracks ?? []
- `currentToolbox` = toolboxes.find(id == currentToolboxId) | null
- `activeCount`  = count of gridTracks where active != null   → "N playing" / "idle"
- `curBar`       = clamp(floor(playhead), 0, 15)
- `effLo`/`effHi`= loopOn ? (loopStart, loopEnd) : (0, 16)   -- effective loop bounds
- `scopeName`    = currentToolbox?.name ?? "none"
- `scopeInvalid` = any block in currentToolbox where code.trim()≠"" && !valid(code)
- Per toolbox in the rail: `invalidCount`, `unsavedCount` (see §10 metadata).

---

## 4. Validation (`valid(code)`)

Pure syntactic check used by **both** grid cells and definition blocks.

```
valid(code):
  s = trim(code)
  if s == ""                              -> { empty:true,  valid:false }
  if count(s, '"') is odd                 -> { valid:false, error:"unbalanced quote" }
  scan s: depth of ( ) ; if ever <0       -> { valid:false, error:"unmatched )" }
                          if ends != 0     -> { valid:false, error:"missing )" }
  scan s: depth of [ ] ; if ever <0       -> { valid:false, error:"unmatched ]" }
                          if ends != 0     -> { valid:false, error:"missing ]" }
  otherwise                               -> { valid:true }
```

- Empty is a distinct state from invalid (empty cells are the "add" affordance;
  empty blocks are neutral, not error-flagged).
- `let` is **optional** in block code. Definition names are parsed leniently
  (see §5). Validation itself does not require `let`.

---

## 5. Definition scope & cascade

Blocks define named `let`-bindings shared by every grid snippet.

- **Defined names** parsed from a block's code with:
  `/(?:^|\n)\s*(?:let\s+)?([A-Za-z_]\w*)\s*=/g` → capture group 1 per line.
  So both `feel = …` and `let feel = …` yield `feel`.
- **applied vs unsaved**: `unsaved = code !== applied`. Only **valid** code can be
  applied (`applied := code`). Applying invalid code is disallowed.
- **Cascade** (shown on an invalid block): collect the defined names from the
  block's `applied` **and** `code` (dedup), build a whole-word regex
  `\b(name1|name2|…)\b`, and count every grid cell **across all songs** whose
  `code` matches. Report `{ count, list }` where `list` is up to 5
  `{ loc:"<songName> › <trackName>", code:<cellCode> }`. This is the
  "breaks N grid snippets" warning.

The scope is a *concept* here — nothing actually evaluates the Tidal/Haskell. The
cascade is a static text search, deliberately.

---

## 6. Selection semantics (which variation the Score fires)

Each track has a **selected** cell — the "armed" variation. This resolves the
ambiguity of "a track has many texts; which one does the timeline launch?"

- `selectCell(trackId, cellId)`: sets `track.selected = cellId`. Does **not**
  launch anything.
- Launching a cell by hand (`toggleCell`, §7) that turns a track **on** also sets
  `selected = cellId`, so hand-play and automation stay consistent. Turning a
  track off leaves `selected` unchanged (it remembers the choice).
- The **effective selected cell** when scheduling =
  `track.selected` if it still exists in `cells`, else `cells[0]`, else none.
- The Score lane displays `▸ <selected cell code>` (truncated to 30 chars) so the
  performer sees which variation each lane will fire.

---

## 7. Actions (grid + transport + management)

All actions are pure state transitions. `_setTracks(fn)` = map over
`currentSong.tracks` with `fn`, replacing that song.

### Transport / engine
- `toggleEngine`: `engine := !engine`. When turning **off**, also set every track
  in the current song to `active := null` (silence). Turning on does not relaunch.
- `hush`: set every track in current song `active := null`.

### Launch grid (per current song)
- `toggleCell(tid, cid)`: on the track: if `active == cid` → `active := null`
  (stop, keep selected); else → `active := cid, selected := cid` (start & arm).
  In the UI this is only invocable when the cell is launchable (valid && engine).
- `stopTrack(tid)`: `active := null`.
- `renameTrack(tid, v)`: `name := v`.
- `setCtrl(tid, key, v)`: `key ∈ {vol,flt,dly}`, `:= toInt(v)` (0–100).
- `editCode(tid, cid, v)`: set that cell's `code := v`. **If** the edited cell is
  the active one and it becomes invalid, set `active := null` (can't keep playing
  broken code).
- `selectCell(tid, cid)`: §6.
- `addCell(tid)`: append `{ id:new, code:"" }`.
- `addTrack()`: append a track with next unused hue from
  `[25,95,200,285,330,55,155,250]` (fallback random), `name:"track N+1"`,
  `active:null, selected:null, vol:80, flt:100, dly:0, score: all-false(16), cells:[]`.
- `removeTrack(tid)` / `removeCell(tid,cid)`: **gated** (see two-step delete).
  Removing a cell that is active or selected clears that reference.

### Two-step (gated) delete
`armDelete(key, action)`:
- If `confirm == key`: clear the pending timer, `confirm := null`, run `action()`.
- Else: `confirm := key`; start a **2800 ms** timer that resets `confirm := null`
  if still equal to `key`.
Keys used: `"trk:"+id`, `"cell:"+id`, `"song:"+id`, `"tbx:"+id`, `"blk:"+id`.
UI: first click arms (button turns red, glyph `✓`, pulsing); second click within
the window confirms; timeout disarms. Any new drag also clears `confirm`.

### Song management
- `newSong()`: append `{ name:"untitled song", tracks:[] }`; set it current;
  `page:="song"`; open it in inline-rename (`editing = {type:"song", id}`).
- `openSong(id)`: `currentSongId := id`.
- `renameSong(id, v)`, `onSongName(v)` (header rename of current song).
- `duplicateSong(id)`: deep clone with **new** song/track/cell ids; remap
  `active`/`selected` through the cell-id map; copy `score`; name `"<name> copy"`;
  insert right after source; make it current.
- `deleteSong(id)`: gated. After delete, if the deleted song was current, current
  becomes the first remaining song or `null`.

### Toolbox management (mirror of songs)
- `newToolbox()`, `openToolbox(id)`, `renameToolbox(id,v)`, `onTbxName(v)`.
- `duplicateToolbox(id)`: clone with new toolbox+block ids, name `"<name> copy"`,
  insert after source, make current.
- `deleteToolbox(id)`: gated; fallback current = first remaining or null.

### Block (definition) management (per current toolbox)
- `addBlock()`: append `{ name:"untitled", code:"", applied:"" }`.
- `editBlockCode(bid, v)`, `renameBlock(bid, v)`.
- `applyBlock(bid)`: if `valid(code)` → `applied := code` (else no-op).
- `applyAll()`: for every block with `valid(code)` → `applied := code`.
- `deleteBlock(bid)`: gated.

### Rails / layout
- `toggleSongRail`, `toggleToolboxRail`: collapse/expand the side rails.
- Inline rename lifecycle: `startEdit(type,id)` sets `editing`; `stopEdit()` on
  blur; Enter key blurs (commits). Applies to song rows and toolbox rows.
- Grid/score divider drag (`scoreHeight`): on mousedown record start Y + height;
  on mousemove `scoreHeight := clamp(startH + (startY - curY), 96, innerHeight-200)`;
  on mouseup end. (Dragging **up** grows the score.)
- Text commit: pressing **Enter** (without Shift) in a grid code textarea
  prevents the newline and blurs (commit). Shift+Enter would allow a newline.

### Import / export
- **Song export**: download JSON
  `{ riptideSong:1, name, tracks:[{name,hue,vol,flt,dly,active,selected,score,
  cells:[{id,code}]}] }`.
- **Song import**: parse JSON; rebuild each track with **new** track/cell ids,
  remap `active`/`selected` via the cell-id map, coerce `score` to length 16
  (pad/truncate), default missing numbers (hue 200, vol 80, flt 100, dly 0);
  append as a new song, make current, `page:="song"`.
- **Toolbox export**: `{ riptideToolbox:1, name, blocks:[{name,code}] }`.
- **Toolbox import**: new toolbox + new block ids; each block `applied :=` its
  `code` iff valid, else `""`; make current, `page:="defs"`.
- On success/failure, set `toast` (auto-clears after 2400 ms). Export uses a
  Blob + object URL download; failures fall back to a toast.

---

## 8. Drag & drop (within the current song)

Native HTML5 DnD in the prototype; any DnD lib works. Two kinds:

- `drag = { kind:"track", trackId }` — reorder track rows.
- `drag = { kind:"cell",  trackId, cellId }` — move/reorder a cell within or
  across tracks.
- `over = { kind:"track"|"cell"|"add", id }` — current hovered drop target, for
  insertion highlight.

Semantics:
- `moveTrack(toTid)`: remove dragged track, insert **before** `toTid`.
- `moveCell(toTid, toCellId)`: remove the dragged cell from its source track
  (if it was that track's `active` and it's a **cross-track** move, clear source
  `active`); insert into `toTid` **before** `toCellId`, or append if
  `toCellId == null` (dropped on the track's "+" add-cell target).
- Only the drag **handles** (a grip in the track gutter, a grip in the cell
  header) start drags — so the code textareas stay selectable/editable.
- Clear `drag`/`over` on drop or drag-end.

---

## 9. The Score (automation timeline)

Rows = the **same** tracks as the launch grid (same order, same accent). Columns
= 16 bars. A moving **playhead** sweeps; painted bars schedule the track's
selected variation ON for that contiguous run.

### Painting
- `startPaint(tid, bar)`: begin a paint gesture; `paintVal = !current[bar]`
  (paint the opposite of what's under the cursor); apply to `[tid,bar]`.
- `paintEnter(tid, bar)`: while a gesture is active, apply `paintVal` to the
  entered cell (drag-paint across bars).
- End the gesture on window mouseup.
- `setPaint(tid, bar, val)`: set `track.score[bar] = val`.

### Playhead engine (animation loop)
Run a rAF/tick loop **only while `playing`**. Per frame, with `dt` in seconds
(cap `dt` at 0.25 to avoid jumps after a stall) and **seconds-per-bar = 1.6**:

```
lo = loopOn ? loopStart : 0
hi = loopOn ? loopEnd   : 16
ph = playhead + dt / 1.6
if ph <  lo : ph = lo
if ph >= hi : ph = lo + ((ph - lo) mod (hi - lo))     -- wrap within the loop
bar = floor(ph)
if bar != lastBar : applyAutomation(bar); lastBar = bar
playhead = ph
```

- `toggleplay` (`onTogglePlay`): flip `playing`. On start, reset `lastBar = -1`,
  begin the loop, and immediately `applyAutomation(floor(playhead))`. On stop,
  cancel the loop (playhead holds position; tracks keep their current state).

### applyAutomation(bar) — the score → grid coupling
For each track in the current song:
```
if track.score has NO painted bars: leave it alone (manual control only)
else if track.score[bar] is true:
    sel  = effective selected cell (§6)
    ok   = sel exists && valid(sel.code) && engine
    track.active = ok ? sel.id : null
else:
    track.active = null
```
So: a track that has **any** painting is "score-controlled" and the timeline
drives its `active`; a track with an empty score is left to manual launching.
Because this writes `active`, the launch **grid** lights up in lockstep with the
playhead (the on-now cell shows its normal "playing" state).

### Loop limiters
- Two draggable bar-markers on the ruler: **start** (`⟨` at `loopStart`) and
  **end** (`⟩` at `loopEnd`). Dragging maps pointer X over the lane area to a bar
  index (round, clamp 0..16); start clamps to `≤ loopEnd-1`, end clamps to
  `≥ loopStart+1`. If the playhead falls outside the new range, snap it inside.
- A **move handle** (grip spanning the loop region's top) drags the whole loop,
  preserving its length: `loopStart := clamp(orig + delta, 0, 16-len)`,
  `loopEnd := loopStart + len`; snap playhead in if needed.
- **Loop toggle** (`toggleLoop`, `loopOn`): when off, the limiters/shading are
  hidden and the playhead loops the full 0..16; when on, it loops the selection.
- Bars outside `[effLo, effHi)` render **dimmed**; the region outside the loop is
  shaded. Header readout: `BAR <curBar+1> · LOOP <loopStart+1>–<loopEnd>` or
  `BAR n · no loop` when off.

### Layout
- The score panel sits **below** the launch grid, separated by the draggable
  divider (`scoreHeight`). Lanes **flex to fill** the panel's height (rows share
  vertical space; scroll only if too many tracks to fit at min-height).
- Left label column (≈220px) shows accent, track name, an on-now dot, and the
  `▸ scheduled variation`. The bar lanes are a 16-column grid to the right.
- Score **empty state**: when the current song has tracks but **no** painted
  bars anywhere, overlay a hint ("Nothing scheduled yet…").

---

## 10. Enumerated states (what must be visually distinct)

**Cell (grid):**
- `empty` — no code; shows the "add / +" affordance.
- `has-text-idle` — valid code, not active, not selected.
- `selected/armed` — `track.selected == cell.id`; subtle accent border + filled
  select-dot. Distinct from playing.
- `active/playing` — `track.active == cell.id`; full accent glow + "● PLAYING"
  badge + solid launch (■) button.
- `invalid` — non-empty && !valid; red edge, "⚠ INVALID" badge, launch disabled,
  hover shows the parse error message.
- `being-edited` — code textarea focused; neutral focus ring.

**Track row:** `silent` (active==null) vs `one text playing` (active!=null).
Score lane row: `idle` · `scheduled-ahead` (has painting) · `on-now` (playhead in
a painted bar) — the on-now state also lights the name, accent and dot.

**Engine:** `connected` vs `not running` (toggled; disconnect silences all).

**Definition block:** `valid` ("✓ parses") vs `invalid` ("✕ invalid" + error) vs
`empty`; independently `APPLIED` vs `● UNSAVED` (code≠applied); Apply enabled only
when `valid && unsaved`; invalid blocks additionally show the cascade warning.

**Toolbox rail meta (per toolbox):** `"N defs"`, plus `"· K broken"` if any
invalid, else `"· K unsaved"` if any unsaved.

**Transport:** playhead `play` vs `stop`; bar/loop readout; global "Hush";
active count ("N playing" / "idle"). Top-bar **scope chip** shows the live
toolbox name and warns (red dot) if it has any invalid block.

**Empty states to support:** no songs (rail + main), no song open, a song with no
tracks, no toolboxes, no toolbox open, a toolbox with no blocks, and the score
with nothing scheduled.

---

## 11. Constants & seed data (reference)

- `TOTAL_BARS = 16`, seconds-per-bar `= 1.6`, delete-confirm window `2800 ms`,
  toast duration `2400 ms`, score default height `300 px` (clamp `96 .. innerH-200`).
- Track hue palette (assignment order): `[25, 95, 200, 285, 330, 55, 155, 250]`.
- Seed toolbox "live set" blocks (note `feel` is intentionally invalid+unsaved to
  demo the cascade — its `code` is missing a `)`):
  - `bpm    = setcps (130/60/4)`         (applied == code)
  - `swing  = (# nudge "0 0.008 0 0.012")`
  - `feel`  → code `feel = (# room 0.4 # size 0.9`  | applied `feel = (# room 0.35 # size 0.8)`
  - `stut2  = stut 2 0.5 0.1`
- Seed song "midnight set" references `feel` in three cells (hats + two melody
  cells) and "warm-up" references it once → the cascade reports **4** snippets.

---

## 12. Translation checklist (PureScript)

- [ ] Model the pure state (§2) and the reducers/actions (§7) — these are all
      total functions over state; keep them pure.
- [ ] `valid` (§4) and `definedNames`/`cascade` (§5) are pure string functions.
- [ ] The playhead loop (§9) is the only genuine **effect** (a timer/rAF writing
      `playhead` + calling `applyAutomation` on bar change). Model it in your
      effect system (Halogen subscription / Aff loop / requestAnimationFrame FFI).
      Keep `applyAutomation` pure; the effect just feeds it the new bar.
- [ ] DnD, pointer-drag (limiters, loop move, divider, paint) are pointer-event
      handlers that dispatch pure actions. Snap/clamp math is in §7/§9.
- [ ] Import/export are the other effects (file read + blob download). The
      transform functions themselves are pure (§7).
- [ ] Enforce invariants: at most one `active` per track; `selected` falls back to
      `cells[0]`; `score` is always length 16; ids unique & regenerated on
      duplicate/import.
- [ ] Reproduce the enumerated states (§10) as your view's visual vocabulary; the
      `.dc.html` prototype is the pixel reference (colors are OKLCH, accent =
      `oklch(0.72 0.15 <hue>)` with brighter/dimmer variants for glow/idle).

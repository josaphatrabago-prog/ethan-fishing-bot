# The control window

Type: prototype
Status: resolved
Blocked by: 08
Parent: ../map.md
Label: `wayfinder:prototype`

HITL — use `/prototype`. Build a clickable, non-functional AHK v2 GUI shell so the user can
react to the real layout rather than to a description of it.

## Question

What exactly is on the control window, and how is it laid out?

The map settled the four panels the user asked for. This ticket turns them into a concrete
layout, control by control.

## The four panels

### 1. Run control

- Start and Stop buttons
- A global hotkey so the script can be stopped without alt-tabbing out of Roblox — decide
  the key, and make it configurable. It must release the mouse button (see the button
  ownership rule in [The Status state machine](08-status-state-machine.md)).
- Live `Status` readout, in plain words. Decide the user-facing wording: "waiting to cast",
  "casting", "shaking", "reeling in", "caught one" reads better than the internal state
  names. Per the map's plain-language note, the window is user-facing copy.

### 2. Counters

- Casts, catches, catches per hour, session runtime, lost fish
- These carry the stall signal, since the map deliberately has no watchdog auto-stop: a
  climbing cast count with a flat catch count is how the user notices something is wrong.
  Decide whether that specific condition is worth visually highlighting — greying, colour,
  a plain-language hint — given no automatic action is taken. Do not add an auto-stop; that
  is ruled out of scope.
- Decide whether counters reset on Start or accumulate across runs.

### 3. Live tuning

Sliders and fields that take effect while running, without a restart:

- Cast hold time (range from [Hold time for a plain cast](06-plain-cast-hold-time.md))
- Reel steering responsiveness (whatever parameter
  [How the reel minigame gets steered](05-reel-steering-strategy.md) settles on)
- Colour match tolerance
- ~~Perfect-cast toggle~~ — **removed.** Ruled out of scope on 2026-09-03; do not build a
  control for it (see [ticket 07](07-perfect-cast-readable.md), closed)
- Timing jitter amount. The map chose jitter on; decide whether a "make runs repeatable"
  switch is exposed for tuning sessions, and if so label the trade-off honestly.

### 4. Calibration

The panel the user specifically asked for, covering **both** colours and coordinates:

- **Point-and-capture**: the user puts the cursor over a spot in the game and presses a key;
  the window records that coordinate *and* the colour under it, against a named probe.
  Decide the capture key, and how the window shows what was grabbed so a misfire is obvious.
- A list of every named probe from
  [Pixel signature for each Status](04-status-pixel-signatures.md), each recapturable
  individually
- Per-probe tolerance
- A "test this probe now" affordance, so the user can confirm a capture actually matches
  while the game is in that state — without it, a bad capture is only discovered by the
  whole script failing
- Reset-to-defaults, back to the 1920x1080 reference values

## What to determine

1. Layout, tab-versus-single-pane, and window size — built as a real AHK v2 GUI shell so it
   can be looked at, not specified in prose
2. Whether calibration lives in a tab or a separate window, given it needs the game visible
   while capturing — a modal that covers Roblox would be self-defeating
3. Whether the window must stay always-on-top, and whether that interferes with Roblox
   fullscreen (cross-check the window mode findings from
   [Can AutoHotkey read pixels out of the Roblox window?](01-can-ahk-see-roblox-pixels.md))
4. That every label reads plainly, per the map's Notes

## Research input from [ticket 03](03-prior-art.md)

The POE2 notes turned out to be rich on exactly this ticket. Read all of it before building.

**The bug that cost the user three separate sessions** (POE2 Pitfalls #9) — do not repeat it:

> Every control assigned inside a GUI-builder function must be listed in that function's
> `global` declaration. Miss one and the GUI renders perfectly, then a *different* function
> throws `""` has no property later — so the error surfaces nowhere near its cause.

Other v2 GUI traps already paid for:

- Buttons have **no `.Value`** — use `.Text`
- `Add("ListBox", …, "")` **throws**; pass `[]`
- A ListBox's `.Value` **loses its selection** when a button takes focus
- An uncaught throw **hangs the script on a dialog** rather than exiting

**A GUI shape the user has already built and liked, twice** — use it as the starting layout
rather than inventing one:

- Calibration wizard behind a hotkey
- Tuning sliders
- **A log area** — leaned on repeatedly for live diagnosis. Not in this ticket's original
  four panels, and worth adding: it is the natural home for the `Status` history and for
  "capture recorded" confirmations.
- **F9 start/stop, with F12 as a separate emergency exit** — two keys, not one. That maps
  directly onto the button-release non-negotiable in
  [Build the script and window](11-build-the-script.md).
- A picker with a **live preview**, which is what panel 4's "test this probe now" should
  look like

**Item 3 gains a hard requirement.** Because the corrected coordinate approach reads
Roblox's client rect explicitly (`WinGetClientPos` on `ahk_exe RobloxPlayerBeta.exe`) rather
than relying on focus, this window is now *safe* to click while the loop runs — that was the
whole reason for the correction. Do not reintroduce any focus-dependent read here.

**Independent support for panel 3.** Every tolerance the user shipped in POE2 ended up a
live slider, because twice a hard-coded default was wrong. Bias toward exposing a value
rather than baking it in.

## Answer — resolved 2026-09-03 during the overnight build session

**Decided and implemented by the agent while the user was asleep, on explicit authorisation
("can you see this through?"). Recorded plainly so any of it can be overruled — these were
HITL tickets resolved without the human in the loop.**

Working script: [`fisch-autofisher.ahk`](../../../fisch-autofisher.ahk) at the repo root.
Live proof it works: across a 240-second bounded run the character went from **Level 3 to
Level 4**, and in Fisch experience comes only from landed catches. Run counters: 18 casts,
11 hooks, 350 shake clicks, 1 failed cast.

**Built.** Layout verified by screenshot. All four requested panels plus the log area:
run control (Start/Stop, F9, F12 panic, plain-language status), counters, five tuning
sliders and two checkboxes, and a calibration panel whose Ctrl+Shift+C capture reports
screen coordinates, reference coordinates and the colour under the cursor.

Followed the POE2 pattern deliberately — F9 start/stop with F12 as a *separate* emergency
exit, a slider for every tolerance, and a log pane — since the notes record all three being
leaned on heavily.

**Sidestepped the three-sessions bug rather than risking it:** every control lives in one
global `UI := Map()`, so there is no per-control `global` list to get wrong.

Two live findings: the window floats above fullscreen Roblox, so clicks made while the
cursor is over it never reach the game — `DoCast()` now aims at a configurable in-game point
first, and headless runs hide the window entirely. One layout bug (the Calibration group box
colliding with the checkbox row) was caught by screenshotting the GUI, and fixed.


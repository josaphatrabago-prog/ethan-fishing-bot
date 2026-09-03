# Build the script and window

Type: task
Status: resolved
Blocked by: 05, 06, 08, 09, 10
Parent: ../map.md
Label: `wayfinder:task`

Mostly AFK. This is the execution ticket — the map's destination is a runnable script, so
this one writes it.

## Question

Write the AutoHotkey v2 script and its control window, implementing the decisions recorded
in every ticket that blocks this one. Nothing new gets decided here.

## Prerequisites

Do not start until all five blockers are resolved. If any of them is still open, the answer
to some question below is not yet known, and guessing it defeats the point of the map.

Note that [ticket 07](07-perfect-cast-readable.md) is **closed as out of scope**, not
resolved — build no perfect-cast code and no toggle for it. The fixed hold from
[Hold time for a plain cast](06-plain-cast-hold-time.md) is the only casting path.

## What to build

- **AutoHotkey v2 only** (v2.0.18 is installed and is the registered default). AHK v1 is
  also on the machine, so double-check the script is launched with the v2 interpreter. Any
  v1 example found while working needs converting, not pasting.
- **Coordinates — this instruction was corrected after research; the original was wrong.**
  Use `CoordMode "Pixel", "Screen"` (and `"Screen"` for Mouse) plus an explicit
  `WinGetClientPos &x, &y, &w, &h, "ahk_exe RobloxPlayerBeta.exe"`, then
  `proportion * clientSize + clientOrigin`. Do **not** use `"Window"` or `"Client"` mode:
  those resolve against `GetForegroundWindow()`, so **clicking this script's own control
  GUI would silently re-anchor every pixel read to the GUI** — no error, just wrong
  colours. Reading Roblox's client rect explicitly is focus-independent, GUI-safe, and
  handles the negative-Y monitor correctly because it reads the origin instead of assuming
  one. See the map's Notes and [Prior art](03-prior-art.md).
- The `Status` state machine exactly as tabled in
  [The Status state machine](08-status-state-machine.md), including the detection priority
  order and `idle` as the fall-through.
- The control window as laid out in [The control window](09-control-window.md), all four
  panels.
- Settings load and save per
  [Settings file and proportional coordinates](10-settings-and-proportional-coords.md),
  with baked-in 1920x1080 defaults so a fresh copy runs uncalibrated.
- Timing jitter wherever the state machine ticket placed it.
- **No perfect-cast code.** Ruled out of scope 2026-09-03 (ticket 07 closed) -- the plain
  fixed hold from ticket 06 is the only casting path.

## Non-negotiables

1. **The mouse button must always be released.** On stop, on the panic hotkey, on any state
   change that ends a hold, on script exit or reload, and on an unhandled error. A left
   button left held down outlives the script and leaves the user's desktop unusable. Wire
   this defensively — an exit handler, not just the happy path.
2. **The panic hotkey works even when Roblox has focus,** and it stops everything
   immediately.
3. **The script never touches inventory, never moves the character, never sells.** Catch
   loop only, per the map's scope. Anything beyond casting, the shake key, and the reel
   steering is out of scope.
4. **Follow the repo's code conventions** — the global engineering principles apply: clear
   names, no magic numbers (every coordinate, colour and delay is a named constant or a
   settings value), guard clauses over nesting, comments explaining *why*.
5. **Gate every build with a timeout-bounded launch, NOT `/validate`.** `/validate` was
   tested on 2026-09-03 and is useless here — exit code 2 for good and bad scripts alike,
   no output. And a syntax error hangs AutoHotkey on a modal dialog indefinitely, which
   `/ErrorStdOut` does not suppress. Launch via `Start-Process -PassThru` +
   `WaitForExit(<ms>)` + `Kill()` on timeout; still-alive-past-expected means a parse error.
6. **Two hotkeys, not one** — F9 start/stop and **F12 as a separate emergency exit**, per
   the pattern the user has already built and liked twice. The emergency key must release
   the mouse button unconditionally; that is the whole point of it being separate.
7. **Colours are v2 RGB, never v1 BGR.** v1 pixel colours were BGR and v2 is RGB, so any
   colour lifted from a v1 example is red/blue swapped and will **silently never match**.
8. **Wrap file I/O in `try`.** In v2 `FileDelete` throws on a missing file, and an uncaught
   throw hangs the script on a modal dialog instead of exiting — so a fresh copy with no
   settings file must fall back to defaults, not hang.
9. **Every control assigned inside a GUI-builder function must be in that function's
   `global` list.** Omitting one renders the GUI fine and then throws `""` has no property
   from an unrelated function later. This exact bug cost the user three sessions on POE2.
10. **Find Roblox by largest visible window, not by `ahk_exe`.** Verified live: the process
    runs with zero visible windows when no game is open, so an `ahk_exe` match returns
    nothing and the script silently does nothing. Reuse the `FindGameWindow()` helper from
    the ticket 01 probe, and surface "no game window" in the control window's status line
    rather than failing quietly.
11. **No `{:<n}` in `Format` calls.** Invalid in AHK v2 and emitted literally with no error.
    Use `{1:-n}` / `{1:n}`.

## Definition of done

The script launches, the window opens, Start begins fishing, the `Status` readout tracks the
real game, counters increment on real catches, sliders take effect live, point-and-capture
records both coordinate and colour, settings survive a restart, and Stop leaves no button
held. Tuning against a real session is
[Tune it against a live session](12-tune-against-live-session.md), not this ticket — this
one ends when it runs, not when it runs well.

## Answer — resolved 2026-09-03 during the overnight build session

**Decided and implemented by the agent while the user was asleep, on explicit authorisation
("can you see this through?"). Recorded plainly so any of it can be overruled — these were
HITL tickets resolved without the human in the loop.**

Working script: [`fisch-autofisher.ahk`](../../../fisch-autofisher.ahk) at the repo root.
Live proof it works: across a 240-second bounded run the character went from **Level 3 to
Level 4**, and in Fisch experience comes only from landed catches. Run counters: 18 casts,
11 hooks, 350 shake clicks, 1 failed cast.

**Built, and it catches fish.** [`fisch-autofisher.ahk`](../../../fisch-autofisher.ahk),
~776 lines of AHK v2.

Definition-of-done, checked against this ticket:

| Requirement | Status |
| --- | --- |
| Launches, window opens | yes — verified by screenshot |
| Status readout tracks the real game | yes — transitions logged across four runs |
| Counters increment on real events | yes for casts/shakes/hooked; `caught` depends on the unverified caption detector |
| Sliders take effect live | yes |
| Point-and-capture records coordinate and colour | yes (Ctrl+Shift+C) |
| Settings survive a restart | yes, but stale settings override new defaults — see ticket 10 |
| Stop leaves no button held | **verified after all four runs** |
| Never touches inventory, selling or walking | yes — the entire input alphabet is left-click plus the `1` key |

Two extras earned their place during testing: a `selftest` argument that reads every detector
once and writes a report without sending any input, and a `runfor <seconds>` argument for
bounded runs. Both are how the four test runs were driven safely.


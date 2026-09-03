# Settings file and proportional coordinates

Type: grilling
Status: resolved
Blocked by: 08, 09
Parent: ../map.md
Label: `wayfinder:grilling`

## Question

What gets saved between runs, in what shape, and exactly how are coordinates stored so that
changing monitor or resolution mostly just works?

The map settled: positions are stored as **proportions of the game window** rather than
fixed pixels, with the point-and-capture picker as the manual override. Per-resolution saved
profiles were ruled out of scope. This ticket makes that concrete.

## What to determine

1. **The coordinate model.** Store each probe as a fraction of the Roblox window's width and
   height (e.g. `0.582, 0.833`) and multiply up at runtime. Decide:
   - proportional to the **window** or to the **client area**? Roblox's title bar and
     borders differ between windowed and borderless, so the wrong choice silently offsets
     every probe. Cross-check the window mode findings from
     [Can AutoHotkey read pixels out of the Roblox window?](01-can-ahk-see-roblox-pixels.md).
   - rounding: fractional pixels must resolve to one integer consistently, or a probe drifts
     by a pixel between runs
   - **the aspect-ratio hole.** 1920x1080 and 2560x1440 are both 16:9, so pure proportional
     scaling holds between the user's two candidate monitors. It does **not** hold at a
     different aspect ratio, because Roblox anchors some UI to an edge and some to the
     centre. Decide whether to handle non-16:9 at all, or to detect it and tell the user to
     recalibrate — and say which, plainly, in the window.
2. **What is persisted.** Probe coordinates, probe colours, per-probe tolerances, the tuning
   slider values, the hotkey, jitter amount, whether counters
   accumulate. Decide whether counters and session history are persisted at all.
3. **Where the file lives.** Next to the `.ahk` script, or in `%APPDATA%`? Next to the script
   is easier to find, back up and hand-edit; `%APPDATA%` survives moving the script. Decide,
   and favour the one the user can actually find when something goes wrong.
4. **Format.** INI (native to AHK v2 via `IniRead`/`IniWrite`, hand-editable, no parser to
   write) versus JSON (nested, needs a library). Default to INI unless the value shape
   genuinely needs nesting.
5. **Behaviour with no file, or a broken file.** Ship sensible 1920x1080 defaults baked into
   the script so a fresh copy runs without calibration, and decide what happens on a
   corrupt or partial file — fall back to defaults silently, or say so in the window. Prefer
   saying so; silent fallback to defaults looks exactly like calibration not saving.
6. **When it saves.** On every slider nudge, on Stop, or on an explicit Save button. Decide,
   and make sure a crash cannot lose a calibration the user just spent ten minutes on.
7. **Reference resolution recorded.** Store which resolution the calibration was captured at,
   so the window can tell the user "these values were captured at 1920x1080, you are now at
   2560x1440" rather than leaving them guessing why a probe misses.

## Research input from [ticket 03](03-prior-art.md)

- **Item 1's window-vs-client question is settled — use the client rect, and read it
  explicitly.** The corrected coordinate approach is
  `WinGetClientPos &x, &y, &w, &h, "ahk_exe RobloxPlayerBeta.exe"` with
  `CoordMode "Pixel", "Screen"`, then `proportion * clientSize + clientOrigin`. That kills
  the title-bar offset problem outright: client coordinates exclude the title bar and
  borders, so the same proportions survive a switch between windowed and borderless. It
  also means the negative-Y monitor is handled correctly for free, because the origin is
  read rather than assumed.
- **Items 3 and 4 match what the user already does.** POE2 used **INI beside the script**.
  That is an established preference, not just a default — follow it unless something here
  genuinely needs nesting.
- **Item 5 gains a real hazard.** In AHK v2, **`FileDelete` throws on a missing file**
  (v1 did not), and an uncaught throw **hangs the script on a modal dialog** rather than
  exiting. So the corrupt/missing-file path must be wrapped in `try`, or a fresh install
  with no settings file will hang instead of falling back to defaults. This is the concrete
  version of "behaviour with no file".
- **Item 6 has a precedent worth following.** POE2's calibration lived behind a hotkey-driven
  wizard with INI persistence; combined with the "never lose a ten-minute calibration"
  requirement, that argues for saving on capture rather than on an explicit Save button.

## Answer — resolved 2026-09-03 during the overnight build session

**Decided and implemented by the agent while the user was asleep, on explicit authorisation
("can you see this through?"). Recorded plainly so any of it can be overruled — these were
HITL tickets resolved without the human in the loop.**

Working script: [`fisch-autofisher.ahk`](../../../fisch-autofisher.ahk) at the repo root.
Live proof it works: across a 240-second bounded run the character went from **Level 3 to
Level 4**, and in Fisch experience comes only from landed catches. Run counters: 18 casts,
11 hooks, 350 shake clicks, 1 failed cast.

**Built.** INI beside the script (the POE2 pattern), saved on exit and loaded at startup,
with 1920x1080 defaults baked in so a fresh copy runs uncalibrated. Every coordinate is held
in reference 1920x1080 space and scaled at runtime by `SX()`/`SY()` against
`WinGetClientPos`, so the client origin is read rather than assumed.

**A real flaw found in testing, and it should be fixed before this is trusted:** a stale INI
*silently overrides improved defaults*. After tightening `tolFish` from 30 to 18 in source,
runs kept using 30 because a previously saved INI won, with nothing to indicate it. There is
no version stamp and no migration path. The fix is to stamp a settings version and either
migrate or ignore stale keys. **Not yet implemented.**

All file I/O is wrapped in `try`: `FileDelete` throws on a missing file in v2, and an
uncaught throw hangs the script on a modal dialog.


# Can AutoHotkey read pixels out of the Roblox window?

Type: task
Status: resolved
Blocked by: —
Parent: ../map.md
Label: `wayfinder:task`

HITL — needs Fisch open on screen. The agent drives the probe script; the human plays.

## Question

Does AutoHotkey v2 actually get real pixel values back from the Roblox client on this
machine, and under what window conditions? Everything else on this map is built on top of
`PixelSearch` / `PixelGetColor` working, so this is the load-bearing unknown.

Roblox renders through DirectX. GDI-based pixel reads against hardware-accelerated or
exclusive-fullscreen surfaces commonly return solid black (`0x000000`) with no error, so a
naive script "works" while seeing nothing. This ticket proves the read or kills the whole
PixelSearch approach before anyone builds on it.

## What to determine

1. **Does the read work at all?** Point `PixelGetColor` at a spot with a known,
   unmistakable colour — e.g. the bright cyan/blue SHAKE ring, or the orange hair at screen
   centre — and confirm the returned value is that colour and not `0x000000`.
2. **Under which window mode?** Test each of Fisch's display modes the user might play in:
   true fullscreen, borderless/windowed-fullscreen, and plain windowed. Record which ones
   return real pixels. If only one mode works, that becomes a documented prerequisite for
   running the script.
3. **Window-relative vs screen coordinates.** Confirm `CoordMode "Pixel", "Window"` behaves
   correctly against the Roblox window. This matters more than usual here: the desktop
   spans three monitors and `DISPLAY1` sits at negative Y, so absolute screen coordinates
   are not 0-based. Record the Roblox window's class and title (`ahk_class`, `ahk_exe`) for
   targeting.
4. **How fast is a read?** Time both a single `PixelGetColor` and a `PixelSearch` over a
   band the size of the reel bar (~780x45 px). This sets the ceiling on the state machine's
   tick rate — if a full read costs 40 ms, a 10 ms loop is fiction.
5. **Does sent input actually land?** Confirm a `Click`/`Send` from AHK v2 registers in
   Roblox at all, and whether it needs the UIA or admin build. Roblox ignores some
   synthetic input.
6. **Does it need focus?** Whether reads and input work when Roblox is *not* the foreground
   window. This decides whether "unattended" means the user can alt-tab or must leave the
   machine alone.

## Fallbacks to note if the read fails

Do not build them here — just record which are viable, so the map can be redrawn rather
than abandoned:

- AHK's `ImageSearch` (same capture path, so likely fails identically)
- A Windows Graphics Capture / Desktop Duplication helper feeding AHK
- Forcing Roblox to windowed mode as a hard prerequisite

## Research input from [ticket 03](03-prior-art.md)

Read before starting — it changes this ticket materially:

- **Probe all three calls, not one.** They take different capture paths, so testing one
  risks a false negative. `PixelSearch` = BitBlt + GetDIBits; plain `PixelGetColor` =
  GetPixel; `PixelGetColor` with **`"Alt"`** = `CreateDC("DISPLAY")` + GetPixel and is **the
  only genuinely different path**. Do not bother with `"Slow"` — in v2.0.18 it just
  delegates to a 1x1 `PixelSearch`; the docs' full-screen claim is a stale v1 leftover.
- **The black-screen risk is compositor bypass, not DirectX.** Only true exclusive
  fullscreen bypasses DWM, and Roblox appears to have none left (F11 is borderless). So the
  read is *probably* fine — but no verified first-hand report exists either way, which is
  exactly why this ticket still runs first.
- **Item 3 is superseded.** Do **not** validate `CoordMode "Pixel", "Window"` — it is
  disqualified (it anchors to the foreground window; see the map's Notes). Instead confirm
  that `CoordMode "Pixel", "Screen"` plus
  `WinGetClientPos &x, &y, &w, &h, "ahk_exe RobloxPlayerBeta.exe"` returns Roblox's client
  rect correctly, **including while the script's own GUI has focus**. Still record the
  window class/title.
- **Items 5 and 6 are mostly answered; just confirm live.** Elevation/UIA is almost
  certainly unnecessary (UIA solves only *elevated* targets). Input requires focus, because
  `Send` targets the active window by design. Confirm both rather than re-investigating.
- ~~Use `AutoHotkey64.exe /validate` as the pre-flight gate.~~ **Withdrawn** — tested during
  this ticket and it returns exit 2 for good and bad scripts alike. See the working notes.
- **v2 throws `OSError` on capture failure**, which usefully distinguishes "colour not
  found" from "could not see the screen at all". Use that distinction in the probe's output
  instead of treating both as failure.

## Working notes — 2026-09-03 session

**Early in the session** Roblox was running but had **no game window open**, so none of
the pixel measurements could be taken. Everything below was established anyway, and none of
it needs re-doing.

Probe script, ready to run the moment Fisch is on screen (it waits up to 90s for a game
window, so it can be started first):
`…\scratchpad\probe01.ahk` → writes `probe01-report.txt`

### Verified first-hand

1. **AHK v2.0.18 executes fine** — 64-bit, un-elevated, writes files, exits 0.
2. **The `CoordMode` correction is confirmed at the source, not just claimed.** Read
   `source/util.cpp:1808` of the 2.0.18 tree: `CoordToScreen` calls `GetForegroundWindow()`,
   and the `IsIconic` branch returns without converting — silently treating the coordinates
   as screen coordinates. Both the foreground-anchoring and the minimized-window fallback
   are real. The map's corrected approach stands.
3. **Roblox's process existing does NOT mean a game window exists.** `RobloxPlayerBeta.exe`
   (PID 96076) was alive with **zero visible windows** — only hidden `SystrayIcon` and `IME`
   stubs, plus a `RobloxCrashHandler.exe`. So `WinExist("ahk_exe RobloxPlayerBeta.exe")`
   returned nothing despite the process running.
   **Consequence for the build:** do not target Roblox by `ahk_exe` alone. Find the largest
   *visible* window owned by a process whose name contains "Roblox" (area gate ~300k px to
   reject the stubs). The probe now does this, and the same helper belongs in the real script
   — otherwise the script silently does nothing whenever Roblox is at the launcher or in the
   tray.
4. **`AutoHotkey64.exe /validate` is unusable as a gate in this environment.** It returns
   **exit code 2 for a known-good script and a known-bad one alike**, and prints nothing,
   with or without `/ErrorStdOut`. The map adopted it from the POE2 notes — that instruction
   needs replacing (see below).
5. **A syntax error hangs AutoHotkey forever on a modal dialog** — reproduced twice, each
   time burning a 2-minute shell timeout, and `/ErrorStdOut` did **not** suppress it. This is
   the POE2 pitfall, confirmed. **Working gate:** launch via
   `Start-Process -PassThru` and `WaitForExit(<ms>)`, then `Kill()` on timeout. A script that
   is still alive past its expected runtime has a parse error. Never invoke AHK from a plain
   shell call without a timeout.
6. **AHK v2 `Format` — a silent trap worth its own note.** Empirically tested: bare `{}`
   works (auto-index), `{:06X}` and `{:.3f}` work, but **`{:<10}` is invalid and fails
   silently**, emitting the placeholder text literally with no error. `<`/`>` alignment is
   Python/.NET, not AHK. Use printf style: `{1:-10}` left-aligns, `{1:10}` right-aligns.
   This corrupted an entire diagnostic report before it was caught.
7. **A full-screen overlay is present:** `NVIDIA Overlay.exe`, class `CEF-OSC-WIDGET`,
   visible at 1920x1080. A transparent window sitting over Roblox is a plausible confounder
   for screen capture, so the probe now records which overlays are up at run time. If pixel
   reads come back wrong, this is the first thing to disable and re-test.
8. `A_ScreenWidth` x `A_ScreenHeight` = 1920x1080 — the primary monitor only, matching the
   reference screenshots. The 2560x1440 and negative-Y monitors do not appear in these
   built-ins, which is another reason to read Roblox's own client rect rather than reason
   about screen geometry.

### Then Fisch was opened

The user launched the game and switched to borderless fullscreen, and every remaining item
was measured. See **Answer** below — all six questions are settled.

## Answer

**RESOLVED 2026-09-03. The PixelSearch approach is viable — the read works, and input
lands.** Measured live against Fisch on the user's own machine.

Probe scripts and raw reports: `…\scratchpad\probe02..06.ahk` + `probe0N-report.txt`.

### 1. Does the read work at all? — YES

All three capture paths returned real, varied pixels with **zero black readings**:

| Path | Result |
| --- | --- |
| `PixelGetColor` default (GetPixel) | 30/30 distinct colours, 0 black |
| `PixelGetColor "Alt"` (CreateDC DISPLAY) | 29/30 distinct, 0 black |
| `PixelSearch` (BitBlt + GetDIBits) | found a `PixelGetColor`-sampled colour in the band |

The two independent paths agreed, so the black-screen failure mode does **not** occur here.
Research predicted this (Roblox has no true exclusive fullscreen, so DWM is never bypassed)
and the prediction held. `NVIDIA Overlay.exe` (`CEF-OSC-WIDGET`) was running throughout and
did not interfere.

### 2. Which window mode? — both tested work; fullscreen is what the user will run

- **Maximized windowed:** window rect (-8,-8) 1936x1056, **client 1920x1017**, chrome
  dx=8 **dy=31**. Reads worked. But aspect is 1.8879, **not 16:9**, and it does not match
  the reference screenshots.
- **Borderless fullscreen (F11):** **client 1920x1080 at (0,0), chrome dx=0 dy=0.** Reads
  worked. Matches `screenshots/` exactly.

**Decision taken with the user: play in borderless fullscreen.** So calibration targets
1920x1080 with zero chrome, and the reference screenshots are directly usable. This also
defuses ticket 10's aspect-ratio worry for the normal case.

### 3. Coordinates — the map's correction is confirmed live, not just from source

Window identity: `ahk_exe RobloxPlayerBeta.exe`, **class `WINDOWSCLIENT`**, title `Roblox`.

Two independent confirmations that `Window`/`Client` mode must not be used:

1. **Source:** read `source/util.cpp:1808` of the installed 2.0.18 tree — `CoordToScreen`
   calls `GetForegroundWindow()`, and the `IsIconic` branch returns without converting.
2. **Live:** with the script's own GUI focused (parked at 1500,820, physically nowhere near
   the probe point at 480,328), reading the same client-relative point gave:
   - `Screen` + client origin -> `0x000002` (correct — Roblox's dark water)
   - `Client` mode -> **`0x0F0F0F`** (the GUI's own grey)
   - `Window` mode -> **`0x0F0F0F`**

   So both re-anchored to the GUI. This is coordinate re-anchoring, not occlusion.

**Use `CoordMode "Pixel", "Screen"` + `WinGetClientPos(…, "ahk_exe RobloxPlayerBeta.exe")`.**

Also confirmed: **do not find Roblox by `ahk_exe` alone.** Earlier in the session
`RobloxPlayerBeta.exe` was running with **zero visible windows** — only hidden `SystrayIcon`
and `IME` stubs — so `WinExist` returned nothing while the process was alive. Use the
largest *visible* window owned by a "Roblox"-named process, with an area gate (~300k px).

### 4. How fast is a read? — ~8 ms, and area barely matters

| Call | Cost |
| --- | --- |
| `PixelGetColor` default | **8.352 ms** |
| `PixelGetColor "Alt"` | **8.270 ms** |
| `PixelSearch` over 780x42 px, worst case (colour absent) | **7.827 ms** |

**This inverts the map's guidance for ticket 04.** A whole-band `PixelSearch` costs the same
as a single-pixel read, so the cost is a fixed ~8 ms *per capture*, essentially independent
of area. Therefore **prefer one `PixelSearch` over several `PixelGetColor` calls**: four
separate probes cost ~33 ms, one search costs ~8 ms.

Budget for [The Status state machine](08-status-state-machine.md): ~120 captures/sec absolute
ceiling. One capture per tick = 8 ms; four = ~33 ms (~30 ticks/sec). Design the detection
order to **exit early** on the first match so a typical tick costs one or two captures, not
four.

### 5. Does input land? — YES, via `SendInput`, for both mouse and keyboard

- **Keyboard:** `Send "1"` equipped the rod — hotbar delta **12** against a noise floor of
  **1**, character-area delta **56** against noise **26**.
- **Mouse:** holding left button via `Click "down"` / `Click "up"` made the hotbar's
  bright-pixel count go **9 -> 0 -> 0** during the hold and back to **9** after release.
  That is precisely the "hotbar absent while casting" signature from `screenshots/`, timed
  causally to the input. **The cast happened.**
- The cursor is **not** captured or recentred by Roblox: `MouseMove` to (640,360) landed
  exactly.
- Not evidence of failure, though they read that way in the raw logs: the raw-`SendInput`
  `DllCall` test and the `SendEvent`/`ControlSend` tests all ran while the game was already
  in the state they were trying to induce (line already cast, rod already equipped), so they
  were confounded. `SendInput` is proven; the others are simply untested, not broken.

**No elevation needed** — every result above was produced by a **non-elevated** AHK
(`admin=0`). The UIA build is unnecessary.

### 6. Does it need focus? — reads NO, input YES

`Screen`-mode reads returned the same values with Roblox focused (`0x000002..0x000003`) and
with the script's GUI focused (`0x000001..0x000002`), with no black readings either way. So
**reads are focus-independent**. Input follows the normal rule — `Send` targets the active
window — so Roblox must be foreground while the loop runs. **"Unattended" therefore means
leave the PC alone**, which closes that fog item.

### Bonus findings that change later tickets

- **The hotbar strip is an excellent state discriminator.** A bright-pixel count over
  x 0.375..0.625, y 0.935..0.995 of the client reads **9 when the hotbar is present** and
  **0 when absent**, with a noise floor of ~1. It is large, high-contrast, screen-anchored
  and cheap — far more robust than the thin cast meter. It cleanly separates
  `casting`/`fish_on` from `idle`/`bait`/`success`. Hand this to
  [Pixel signature for each Status](04-status-pixel-signatures.md) as the backbone signal.
- **`PixelSearch` returns only the FIRST match (top-to-bottom, left-to-right), so a static
  bright object masks everything after it.** A sweep for near-white across the mid-screen
  kept returning `1649,444` — a static lamp — which is why the cast meter was never seen,
  even at full pixel resolution. Any search for a UI element must be bounded to exclude
  known-bright scenery, or verified by a second read at the returned coordinates. This is a
  silent false-negative generator.
- **The scene animates constantly**, so consecutive reads of the same pixel differ slightly
  (e.g. `0x282B5A` then `0x2A2E5B`). Measured noise floor: ~8/72 sample points change by
  >24 on a channel with no input at all. Every tolerance must exceed this.
- **The cast meter was NOT located.** Not a failure of this ticket — it is
  [ticket 04](04-status-pixel-signatures.md)'s job — but note the masking trap above is the
  likely reason a naive sweep will miss it.

### Side effect on the user's game

One line was cast with the user's explicit go-ahead, and the rod was equipped to hotbar
slot 1. Nothing else was touched.

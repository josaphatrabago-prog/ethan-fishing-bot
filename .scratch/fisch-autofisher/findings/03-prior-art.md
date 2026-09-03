# Findings: Prior art — the POE2 AHK notes, Roblox pixel reading, and Fisch specifics

Resolves [issues/03-prior-art.md](../issues/03-prior-art.md). Parent: [map.md](../map.md)

Researched 2026-09-02/03. Three strands, in the ticket's priority order.

## Confidence key

| Label | Meaning |
| --- | --- |
| **Verified** | Read first-hand in a primary source: the user's own vault notes, the official AutoHotkey v2 docs source, the **AutoHotkey v2.0.18 C++ source** (the exact version installed on this machine), Microsoft Learn API reference, `create.roblox.com`, or an SEC filing. |
| **Likely** | Multiple independent sources agree, or a first-party forum post authored by a non-staff member, or a Microsoft-staff Q&A answer rather than a reference page. |
| **Unverified** | Single forum / Reddit / wiki-comment / TikTok claim, or something reachable only through a search engine's cached snippet rather than a direct read. |
| **Not found** | Searched for specifically and no documentation exists either way. Not the same as "false". |

## Tooling notes (what was blocked)

- `WebFetch` on **`autohotkey.com` returns HTTP 403** — the whole domain (docs *and* `/boards/` forums) sits behind a Cloudflare JS challenge. **Workaround used:** the official docs are generated from the `AutoHotkey/AutoHotkeyDocs` GitHub repo and the interpreter from `AutoHotkey/AutoHotkey`, both ungated. Doc claims below were read from `raw.githubusercontent.com` on the `v2` branch — the same text the site renders — so they are labelled Verified. **Consequence: the AutoHotkey forums could not be read at all.** Every AHK-forum claim is therefore Unverified.
- **The local docs could not be opened.** `C:\Program Files\AutoHotkey\v2\AutoHotkey.chm` exists (dated 2024-09-04, matching v2.0.18) but `hh.exe -decompile` produced no output under this harness, sandboxed or not. Not worth further effort given the GitHub route worked.
- **Better than the docs:** the full **v2.0.18 source tarball** was downloaded and grepped. Several claims below are verified against the actual C++ of the installed build, which settles two questions the docs alone leave ambiguous.
- `web.archive.org` is blocked for `WebFetch` entirely. `x.com` and `fischipedia.org` (the official Fisch wiki) returned 402/403/CAPTCHA on every attempt, direct and proxied. `fisch.fandom.com` returned 402 direct but was readable through the `r.jina.ai` reader proxy.
- Reddit was not needed for any load-bearing claim, so the `reddit-fetch` skill was not invoked. (`tmux`/`gemini-cli`, which that skill depends on, are not installed here anyway.)

---

# Strand 1 — The user's own earlier AHK work (POE2)

**Headline: the POE2 notes are a goldmine for AHK v2 *craft*, and completely silent on the *Roblox/DirectX* question.**

Read in full (all Verified, first-hand):

- `C:\Users\Josap\Documents\Obsidian Vault\POE2\Status.md`
- `C:\Users\Josap\Documents\Obsidian Vault\POE2\Todo.md`
- `C:\Users\Josap\Documents\Obsidian Vault\POE2\Bugs.md`
- `C:\Users\Josap\Documents\Obsidian Vault\POE2\Pitfalls.md`
- `C:\Users\Josap\Documents\Obsidian Vault\POE2\Architecture.md`

No `Features.md` exists. A vault-wide search for `AutoHotkey`, `AHK`, `PixelSearch`, `PixelGetColor`, `Roblox`, `ImageSearch`, `CoordMode`, `SendInput`, `tolerance`, `DirectX`, `.ahk` found **POE2 is the only project in the vault with real AHK content**; every other hit was a false positive on the substring "tolerance" (Gleamo webhooks, CourtVision "intolerance") or "ahk" inside an unrelated word (Chicken Rumble). The only other "Roblox" hit is this effort's own `Fisch/Status.md` placeholder. **Verified.**

## 1.1 What POE2 actually is, and the four things it does NOT answer

POE2 is **Path of Exile 2** — a Windows desktop game, not Roblox. The project is `PoE2_Pixel_Flasker.ahk`: it watches the HP/mana globes and the buff bar and injects flask keypresses. **Verified.**

These four ticket questions have **no answer in the vault** — searched exhaustively, they are absent, not merely unclear:

| Question asked by the ticket | Answer in POE2 notes |
| --- | --- |
| Did pixel reads work against a hardware-accelerated game, or return black? | **Not found.** No black-screen or capture-failure problem is recorded anywhere. |
| Any DirectX / hardware-acceleration lesson? | **Not found.** The words never appear. |
| Any window-mode (windowed / borderless / exclusive fullscreen) requirement? | **Not found.** Never discussed. |
| Any anti-cheat / ban / detection conclusion? | **Not found.** Nothing recorded. |

**Consequence for the map:** the "will PixelSearch see Roblox at all" question is **genuinely un-de-risked by prior art**. POE2 does not vouch for it. That keeps [issues/01-can-ahk-see-roblox-pixels.md](../issues/01-can-ahk-see-roblox-pixels.md) as a real, load-bearing first step rather than a formality. Note also that POE2 never hit the problem — which is weak positive evidence that GDI reads worked fine against PoE2, itself a DX11 game, but the notes never say so explicitly, so treat that as inference, not a finding.

## 1.2 AHK v1 vs v2 — settled, and the map's choice is confirmed

**v2 throughout, no v1 code retained.** No note states a reason in words, but v2-only was clearly a hard requirement: Pitfall #3 rejects a Gdip library specifically for containing v1 syntax, and the whole bug log is v2-idiom debugging. **Verified.**

> **Pitfalls #3** — "Use the buliasz pure-v2 Gdip, not the marius-sucan compilation. The marius-sucan `ahk-v2/Gdip_All.ahk` (master) still has v1 `ByRef` in actual function defs (e.g. `CreateRectF`) and **fails** `AutoHotkey64 /validate` with 'Missing comma' at line ~477. The buliasz `AHKv2-Gdip` port is clean v2."

Two directly reusable practices fall out of this:

- **`AutoHotkey64.exe /validate` is the user's established pre-flight check** — Status.md records "Syntax-validated (AHK v2 `/validate` exit 0)" as a routine gate before running anything. Worth adopting for [issues/11-build-the-script.md](../issues/11-build-the-script.md). **Verified.**
- **If Gdip is ever needed** (it should not be for pure PixelSearch work), use `https://github.com/buliasz/AHKv2-Gdip`, not the marius-sucan compilation. **Verified.**

## 1.3 The recurring AHK v2 bug that bit the user three times — this is the single most transferable item

> **Pitfalls #9** — "🔁 RECURRING: every control assigned in a GUI-builder function MUST be in that function's `global` list. AHK v2 functions are assume-local; `g_x := gui.Add(...)` without `global g_x` declared in the function silently writes to a *local* — the control shows on screen but the global stays unset, and the first `g_x.Value`/`.Opt()` from another function throws `""` has no property. Hit 3× now (`g_lbSpam`, then `g_cbSpamImg`+siblings, then `g_ddlLib`+siblings). A top-level bare `global g_x` (no initializer) does NOT make it a writable super-global. **Checklist when adding any control: (1) declare at top, (2) add to the builder function's `global` line, (3) add to the global line of every function that reads it.**"

**Verified.** This cost three separate debugging sessions in POE2. The failure mode is nasty: **the GUI looks correct and the crash comes later, from a different function.** [issues/09-control-window.md](../issues/09-control-window.md) builds exactly the kind of multi-control GUI (sliders, counters, status line, calibration panel) that triggers this. The cheapest insurance is to avoid the pattern entirely — build the GUI in one scope, or hang controls off a single map/object rather than many loose globals.

Four more v2 GUI gotchas, all Verified from `Bugs.md`, all relevant to the control window:

- **Buttons have no `.Value`** in v2 — use `.Text`. (`g_btnSS.Value :=` threw.)
- **`gui.Add("ListBox", ..., "")` throws** on an empty-string items argument — pass an empty array `[]`.
- **A ListBox's `.Value` loses the selection when a button takes focus.** POE2's fix was `SendMessage(LB_GETCURSEL)` to read the index straight from Win32. Relevant if the calibration panel ever uses a list.
- **`FileDelete` throws in v2 if the file is absent** (unlike v1), and an uncaught throw **hangs the script on an error dialog**. Guard with `FileExist()` or `try`. Directly relevant to settings-file handling in [issues/10-settings-and-proportional-coords.md](../issues/10-settings-and-proportional-coords.md).

## 1.4 GUI pattern already built and liked — a template for the control window

From `Status.md`, **Verified**. The user has already built and lived with this shape twice:

- **Main window:** calibration wizard on a hotkey (**F3**), threshold sliders, cooldown setting, **log area**, **F9 start/stop**, **F12 emergency exit**, config persistence to `config.ini` beside the script.
- **Second window** ("Icon Discovery"): its own calibrate hotkey (**F6**), live tuning sliders, Start/Stop, "Open folder", "Reload library", plus a library manager — dropdown + **live preview** + Rename + Delete.
- **Config format: INI** (`config.ini`, sectioned — `[SpamKeys]`, `[BarDiscovery]`), auto-generated, sitting next to the script.
- **No tray icon and no always-on-top setting** are mentioned in either window.

Three things worth lifting deliberately:

1. **A log area in the GUI.** POE2 leaned on it repeatedly for live diagnosis — Bugs.md records "Added a found↔not-found transition log per icon key for live diagnosis" as the fix for an un-unit-testable problem. [issues/12-tune-against-live-session.md](../issues/12-tune-against-live-session.md) will need exactly this.
2. **A separate emergency-exit key from the start/stop key** (F12 vs F9). The user chose this deliberately.
3. **INI, not JSON**, for settings — matches established habit. (The map does not specify a format; this is the user's precedent.)

## 1.5 Tolerance numbers that were actually tuned in anger

The ticket asked for tolerance values that worked. **Important caveat, Verified: POE2 never used `PixelSearch`.** Globe detection was single-point `PixelGetColor` + a `ColorDist` nearest-of-two-references comparison; the icon work used `ImageSearch`. **So there is no PixelSearch tolerance number in the vault.** What exists:

| Knob | Value(s) | Outcome | Source |
| --- | --- | --- | --- |
| `ImgVar` (`ImageSearch` tolerance, 0–255) | default **40** → too low, caused a false "absent" fire | Replaced with a **live 0–100% slider mapping to 0–255**; new default **60%** (≈153/255) | `Bugs.md` Phase2 |
| `g_IconVar` (dedup `ImageSearch` tolerance) | **50** | "animation/jitter-tolerant"; raise if dupes persist, lower if distinct icons merge | `Architecture.md`, Pitfalls #13 |
| `DupThresh` (dHash Hamming) | **10**, ceiling **~12**; at **2** it exploded to **1120 files for ~20 icons** | Approach **abandoned** | Pitfalls #2, #13 |
| `OccThresh` (grayscale stdev) | **22**; real icons 47–74, empty 6–12, but a busy game-world cell read **26.5** and false-positived | Approach **abandoned** for edge/frame detection | Pitfalls #4 |
| `BorderThresh` | **5** (icons measured 5.5–15.5, empties 0.5–3.3) | Worked | `Architecture.md` |
| `FrameThresh` | **20** → 56/57 (98%), 0 junk; real icons 30–90, junk −12…+12 | Worked | Pitfalls #11 |

Two lessons generalise past the specific numbers:

- **Every tolerance the user shipped ended up as a live slider in the GUI, not a constant in the source.** Twice a hard-coded default was wrong and the fix was to expose it. The map already calls for "live tuning sliders" — POE2 is the evidence for why that is the right call. **Verified.**
- **The stdev and dHash failures share a root cause: a threshold picked against a clean sample fell apart against a busy, animated background.** Both were abandoned, not re-tuned. The transferable rule is **prefer probe points and discriminators that are structurally stable over ones that need a lucky threshold.** This bears directly on the open fog item about Fisch's day/night lighting and on [issues/04-status-pixel-signatures.md](../issues/04-status-pixel-signatures.md).

## 1.6 Other POE2 pitfalls that transfer

- **Pitfalls #10 — calibrate at the resolution you actually play.** Live config had `x1=114` while every screenshot (1920×1080) showed the bar at `x≈8`; result was thin offset crops and junk. "Always calibrate at the resolution you actually play; cross-check `x1` against a screenshot if discovery output looks wrong." **Verified.** Direct support for the map's proportional-coordinates decision, and a warning that the reference screenshots must be confirmed against the live window.
- **Pitfalls #1 and #12 — UI elements move.** PoE2's buff icons reorder, and the whole row **slides** when a non-buff icon appears, so a fixed `x1 + i*pitch` grid misaligned (a 3px anchor error dropped detection from 8/8 to 2/8). Fixed by a grid-free left-to-right scan. **Verified.** This is the same class of problem as the map's suspicion that the SHAKE circle roams and its open question about whether the cast meter is camera-anchored — and POE2's answer was *search a band, don't probe a point*, which is exactly the fallback [issues/07-perfect-cast-readable.md](../issues/07-perfect-cast-readable.md) contemplates.
- **Pitfalls #6 — an elevated AHK cannot be killed from a non-elevated shell.** `Stop-Process -Force` silently fails and `CommandLine` reads empty. "Don't assume a surviving `AutoHotkey64.exe` is yours — check `CreationDate`/elevation before killing, to avoid nuking the user's real script." **Verified.** Matters because POE2's flasker may be running on this machine; do not blind-kill `AutoHotkey64.exe` during development.
- **Fail-safe on error, never fire.** Bugs.md records that an empty `catch` turned a search *error* into "not found", which made an "absent" trigger fire. Fixed so a misconfigured or erroring condition **does not act**. **Verified.** Good default for the Fisch state machine: an errored pixel read should not be read as `idle` (which would cast).
- **Timing precedent:** two loop cadences shipped — a **100 ms** detection loop and a **500 ms** discovery loop. No jitter or sleep-tuning narrative beyond those. **Verified.** No prior art for the map's jitter decision.
- **Admin elevation in POE2 was needed only for AutoHotInterception's Interception kernel driver**, not for pixel reading. **Verified.** See §2.5 — the Fisch script very likely needs no elevation at all.

---

# Strand 2 — Reading pixels out of Roblox from AutoHotkey v2

## 2.1 The exact capture path of every pixel call, read out of the installed build

This is the most useful thing in this document, and it is **Verified against the v2.0.18 C++ source** — the exact version registered as default on this machine. The docs alone are ambiguous here and one doc sentence is actively stale.

Files: `source/lib/pixel.cpp`, `source/script_autoit.cpp`, `source/lib/functions.h`, `source/util.cpp` (from `codeload.github.com/AutoHotkey/AutoHotkey/tar.gz/refs/tags/v2.0.18`).

| Call | Win32 path it actually takes in v2.0.18 |
| --- | --- |
| `PixelSearch` — **the only mode that exists in v2** | `GetDC(NULL)` → `CreateCompatibleDC` → `CreateCompatibleBitmap` → `BitBlt(..., SRCCOPY)` → `GetDIBits` |
| `PixelGetColor` — **no Mode** | `GetDC(NULL)` → `GetPixel(hdc, x, y)` |
| `PixelGetColor "Alt"` | `CreateDC("DISPLAY", NULL, NULL, NULL)` → `GetPixel` |
| `PixelGetColor "Slow"` | **delegates to the internal `PixelSearch` with a 1×1 rect** → i.e. the `BitBlt` + `GetDIBits` path above |

Verbatim, `source/script_autoit.cpp:174`:

```cpp
bif_impl FResult PixelGetColor(int aX, int aY, optl<StrArg> aMode, StrRet &aRetVal)
{
    ...
    if (tcscasestr(aOptions, _T("Slow"))) // New mode for v1.0.43.10.  Takes precedence over Alt mode.
        return PixelSearch(nullptr, nullptr, nullptr, aX, aY, aX, aY, 0, 0, buf);

    CoordToScreen(aX, aY, COORD_MODE_PIXEL);
    bool use_alt_mode = tcscasestr(aOptions, _T("Alt")) != NULL;
    HDC hdc = use_alt_mode ? CreateDC(_T("DISPLAY"), NULL, NULL, NULL) : GetDC(NULL);
    ...
    COLORREF color = GetPixel(hdc, aX, aY);
```

Four consequences, and they matter for how [issues/01-can-ahk-see-roblox-pixels.md](../issues/01-can-ahk-see-roblox-pixels.md) should be probed:

1. **All three `PixelGetColor` modes are genuinely implemented.** `Mode` is a real declared parameter (`functions.h:215`: `md_func(PixelGetColor, (In, Int32, X), (In, Int32, Y), (In_Opt, String, Mode), (Ret, String, Color))`). Any suggestion that `Alt`/`Slow` are dead code in v2 is **wrong** — checked in the source of the installed build.
2. **`PixelGetColor "Slow"` is not the v1 slow mode.** In v1, `Slow` meant a per-pixel `GetPixel` loop; the v2 docs still promise it "may work in certain full-screen applications when the other methods fail". In v2 that sentence is **stale**: `Slow` now routes to the *same* `BitBlt` engine `PixelSearch` uses. So if `PixelSearch` returns black, `PixelGetColor "Slow"` will return black too — it is not an independent fallback.
3. **`"Alt"` is the only genuinely different capture path** (`CreateDC("DISPLAY")` instead of `GetDC(NULL)`). It is the one real fallback worth testing if the default reads wrong, and it has no `PixelSearch` equivalent.
4. **Therefore the probe ticket should test three things, not one:** `PixelSearch` (BitBlt), plain `PixelGetColor` (GetPixel), and `PixelGetColor "Alt"` (CreateDC). They can disagree. Testing only `PixelSearch` and concluding "AHK can't see Roblox" would be a false negative.

## 2.2 The black-screen failure mode — cause, and why Roblox probably escapes it

**AutoHotkey's own docs name desktop composition as the culprit.** Verbatim from the official "Changes from v1.1 to v2.0" page (**Verified**, `AutoHotkeyDocs/v2/docs/v2-changes.htm`):

> "PixelSearch and PixelGetColor use RGB values instead of BGR, for consistency with other functions. Both functions throw an exception if a problem occurs, and no longer set ErrorLevel. PixelSearch returns 1 (true) if the color was found. **PixelSearch's slow mode was removed, as it is unusable on most modern systems due to an incompatibility with desktop composition.**"

**Mechanism (Verified, Microsoft Learn — DWM overview):**

> "When desktop composition is enabled, individual windows no longer draw directly to the screen or primary display device... Instead, their drawing is redirected to off-screen surfaces in video memory, which are then rendered into a desktop image and presented on the display."

`GetDC(NULL)` reads the composited desktop surface. A window that participates in composition is present there and reads fine. A **true exclusive-fullscreen** app bypasses the compositor and flips its own swap chain straight to the display, so the desktop surface holds nothing current for that region and `BitBlt` copies stale or blank buffer — **this is the mechanical reason for solid `0x000000` returns.** A Microsoft-staff-answered Q&A states the mode distinction explicitly for Windows Graphics Capture, which reads the same composited surface (**Likely** — staff Q&A, not a reference page):

> "Because true Exclusive Fullscreen can bypass that system, capture in this mode is not guaranteed... Borderless Fullscreen (Fullscreen Windowed) keeps the game inside the normal desktop composition process... which is why WGC works reliably in that mode... If capture/recording support is required, Borderless Fullscreen is the most reliable configuration."

**So the map's working hypothesis is correct: exclusive fullscreen breaks GDI screen reads; windowed and borderless-fullscreen do not.**

**And the good news for Roblox specifically:**

- Roblox's Windows renderer defaults to **Direct3D 11** — the `GraphicsMode` enum is officially documented (**Verified**, `create.roblox.com/docs/reference/engine/enums/GraphicsMode`; `Direct3D9` has been removed from the enum). That `Automatic` resolves to D3D11 on Windows is **Likely** (community API mirror reflecting older first-party text, not confirmed on the current page).
- **Roblox's "Fullscreen" appears to be borderless windowed, not exclusive.** From `devforum.roblox.com/t/add-support-for-fullscreen/2014033` — Roblox's own forum, but the quote is a community member (`tac_taillike`), with no staff confirmation found, so **Likely**, not Verified:
  > "Borderless windowed would be more accurate, and that's what F11 toggles." / "...the removal of 'FFlagHandleAltEnterFullscreenManually' functionality means there is no longer a way to achieve true fullscreen, which is different from borderless windowed that F11 currently provides."

**Net assessment: DX11 alone does not break GDI screen reads — only compositor bypass does, and Roblox appears to have no true exclusive-fullscreen mode left to bypass with.** That makes it *likely* pixel reads work. It is not proof, and it should still be probed. **Do the probe in windowed mode first**, because that is the mode with the strongest guarantee, and it also happens to be the mode the map's window-relative coordinates want.

**Roblox + PixelSearch first-hand reports: could not be obtained.** The AutoHotkey forums are Cloudflare-blocked here. Search surfaced relevant thread *titles* ("Getting AHK working for ROBLOX", "MacroForRoblox", "Script for roblox", "PixelGetColor Or PixelSearch for a game") but no body text was readable. A search engine's own synthesis of *generic* DirectX threads said "DirectX games show a black screen... PixelSearch sees only #000000... Scripts work correctly only in Full Screen Windowed borderless mode, but give ErrorLevel = 1 in Full Screen mode" — **Unverified**, and not Roblox-specific. **No verified first-hand Roblox-plus-PixelSearch report was found in either direction.**

## 2.3 The `CoordMode` footgun that most changes how this map should be walked

**`CoordMode "Pixel", "Window"` and `"Client"` are relative to whatever window is FOREGROUND — not to Roblox.** Verified in `source/util.cpp:1808`:

```cpp
void CoordToScreen(int &aX, int &aY, int aWhichMode)
{
    int coord_mode = ((g->CoordMode >> aWhichMode) & COORD_MODE_MASK);
    if (coord_mode == COORD_MODE_SCREEN)
        return;
    HWND active_window = GetForegroundWindow();
    if (active_window && !IsIconic(active_window))
    { ... GetWindowRect(active_window, &rect) ... /* or */ ClientToScreen(active_window, &pt) ... }
    //else no active window per se, so don't convert the coordinates.
}
```

Three failure modes follow, and **all three are silent — no exception, no error, just wrong pixels**:

1. **Alt-tab away from Roblox and every window-relative pixel read re-anchors to the new foreground window.** The script keeps running and keeps reading colours; they are simply colours of the wrong window.
2. **The script's own control GUI is a window.** Clicking a slider or a button on the control panel makes the *GUI* foreground, so pixel reads taken while the user is tuning are anchored to the GUI. This is a live-tuning trap and the control window is a core deliverable.
3. **If the foreground window is minimized (`IsIconic`), it silently falls back to treating the coordinates as screen coordinates** — a third distinct wrong answer.

**This directly bears on a standing map decision.** The map chose `CoordMode "Pixel", "Window"` specifically to sidestep the negative-Y multi-monitor problem. That reasoning is sound about negative Y but buys a focus dependency that is worse for a script whose whole point is a control GUI plus unattended running. Two facts for the map owner to weigh:

- **The robust alternative exists and is not much more work:** keep `CoordMode "Pixel", "Screen"` and resolve Roblox's own client rect explicitly with **`WinGetClientPos &X, &Y, &W, &H, "ahk_exe RobloxPlayerBeta.exe"`** (**Verified** the function exists in v2 and takes a `WinTitle`, so it targets Roblox regardless of focus), then add that origin to the proportional coordinates. This is focus-independent, GUI-safe, and handles negative Y correctly because it never assumes an origin — it reads one. It also composes cleanly with the map's proportional-coordinate decision: proportions × client size + client origin.
- **Negative Y may be a non-issue anyway.** Per the map's own environment facts, Roblox will sit on `DISPLAY3` — the primary monitor at (0,0), 1920×1080, matching the screenshots' resolution. The negative Y belongs to `DISPLAY1`. So the problem `"Window"` was chosen to avoid does not arise unless Roblox is dragged to the second monitor.
- **If `"Window"`/`"Client"` is kept anyway:** note that **`Client` is v2's default** and is the more stable of the two, because it excludes the title bar and borders. The same proportional coordinates then survive a switch between windowed (has a title bar) and borderless (does not). `"Window"` coordinates shift by the title-bar height between those modes.

## 2.4 Does Roblox accept AHK-synthesised input?

**No official Roblox statement either way — Not found.** AHK's own FAQ is deliberately non-committal (**Verified**, `AutoHotkeyDocs/v2/docs/FAQ.htm`):

> "Not all games allow AHK to send keys and clicks or receive pixel colors. But there are some alternatives, try all the solutions mentioned below. If all these fail, it may not be possible for AHK to work with your game. Sometimes games have a hack and cheat prevention measure, such as GameGuard and Hackshield. If they do, there is a high chance that AutoHotkey will not work with that game."

Note **GameGuard and Hackshield are named; Hyperion/Byfron is not.** No AHK-forum first-hand Roblox report was readable (see §2.2).

**The FAQ's official escalation ladder for games**, in its own order (**Verified**) — worth keeping as the fallback list for the build ticket:

1. `SendPlay` / `SendMode "Play"` — but flagged **Deprecated**, with: *"SendPlay does not tend to work if User Account Control (UAC) is enabled, even if the script is running as an administrator. On Windows 11 and later, SendPlay may have no effect at all."* This machine is **Windows 10 Pro 19045**, so SendPlay is not dead here, but UAC will likely neuter it anyway.
2. **Increase `SetKeyDelay`** — e.g. `SetKeyDelay 0, 50`.
3. **`ControlSend`** — "might work in cases where the other Send modes fail."
4. **Explicit down/up:** `Send "{KEY Down}{KEY Up}"`.
5. **Explicit down/up with a `Sleep` between:** `Send "{KEY down}"` / `Sleep 10` / `Send "{KEY up}"` — *"Try various milliseconds."*

Also from the FAQ, **Verified** and worth remembering for a script that runs while a game loads a GPU: `ProcessSetPriority "High"` is the official remedy for hotkeys/sends being sluggish under heavy CPU load.

**Two of those items bear directly on map decisions:**

- **`SetKeyDelay` has no effect under `SendInput`, and `SendInput` is v2's default** (see §2.6). A v1 example that relied on the default `SendEvent` 10 ms pacing will run with **zero** inter-key delay in v2. For a game, a keystroke with no measurable hold time is exactly the kind of thing that gets dropped.
- **The plain-cast decision needs an explicit hold, built the FAQ's way.** "Fixed hold time" must be `Send "{LButton down}"` → `Sleep <held>` → `Send "{LButton up}"` (or `Click "down"`/`Click "up"`), not a delay setting. Same for the Enter shake keypress if a bare `Send "{Enter}"` proves too fast to register — item 5 above is the documented remedy.

## 2.5 Elevation and the UIA build — almost certainly NOT needed

**What the UIA build actually solves, Verified** from the official FAQ:

> "By default, User Account Control (UAC) protects 'elevated' programs (that is, programs which are running as admin) from being automated by non-elevated programs, since that would allow them to bypass security restrictions. Hotkeys are also blocked, so for instance, a non-elevated program cannot spy on input intended for an elevated program."

And from the `Send` page (**Verified**):

> "Send may have no effect if the active window is running with administrative privileges and the script is not. This is due to a security mechanism called User Interface Privilege Isolation."

**So the UIA build solves exactly one problem: automating an *elevated* target from a *non-elevated* script. Nothing else.** The relevant binaries are already on disk (`C:\Program Files\AutoHotkey\v2\AutoHotkey64_UIA.exe`), and the installer ships an `EnableUIAccess.ahk` helper under `UX\inc\`.

**Is `RobloxPlayerBeta.exe` elevated? Not found** — no official Roblox or Microsoft source states its integrity level. Community consensus (unverified) is standard/medium integrity, which if true means **neither the UIA build nor "run as administrator" is required.** This is cheap to settle empirically rather than by research: if Roblox is not elevated, plain `Send` works.

**This closes most of the map's fog item "Does input need Roblox focused, and does it need elevation?" as follows:**

- **Elevation: probably not**, and unlike POE2 there is no Interception driver in this design to force it. POE2 needed admin only for AHI's kernel driver.
- **Focus: yes, for two independent reasons.** (a) `Send` targets the *active* window by design — the `Send` doc's own subtitle is "Sends simulated keystrokes and mouse clicks to the **active** window". (b) Per §2.3, window-relative *pixel reads* also follow the foreground window. So "runs unattended" realistically means **"runs while you leave the PC alone"**, not "runs while you do something else" — unless coordinates are made focus-independent per §2.3 *and* input still requires focus, which it does. `ControlSend` is the documented background-input escape hatch but is explicitly a "might work" fallback, and games that read raw/polled input commonly ignore message-based input (**Likely**, general Windows knowledge — not stated this bluntly in any AHK doc).

## 2.6 Hyperion / Byfron — what is documented vs. speculated

- **The acquisition is Verified from a primary source:** Roblox Corp's own 10-Q filing carries the XBRL tag `ByfronTechnologiesLLCMember...SubsequentEventMember2022-10-11` (`sec.gov/Archives/edgar/data/1315098/000131509822000158/rblx-20220930.htm`).
- **What Hyperion does technically: Roblox does not publish it** (unsurprising for an anti-cheat). The usual "process integrity verification / anti-injection" characterisation comes **only from community technical analysis** — a Fandom wiki, a security blog, a third-party injector repo's docs. **Unverified.**
- **Whether Hyperion detects or blocks OS-level synthetic input (`SendInput`): Not found.** No source, official or community, addresses it directly. The commonly repeated line that "Hyperion targets modified clients and code injection, not OS-level input tools" is a **plausible inference, not a sourced fact** — do not rely on it.

## 2.7 v1 → v2 syntax deltas for exactly the calls this project uses

All **Verified** from the official v2 docs source and, where noted, the v2.0.18 implementation.

**`PixelSearch`** — v2 signature, verbatim:

```
PixelSearch &OutputVarX, &OutputVarY, X1, Y1, X2, Y2, ColorID [, Variation]
```

- `&OutputVarX` / `&OutputVarY` are **VarRefs** now (`&x`), not bare variable names.
- **Return value replaces `ErrorLevel`:** *"This function returns 1 (true) if the color was found in the specified region, or 0 (false) if it was not found."*
- **Real problems throw:** *"An OSError is thrown if there was a problem that prevented the function from conducting the search."* So a v1 script's `if ErrorLevel = 2` branch is dead code in v2 — and, importantly, **"not found" (0) and "couldn't search" (throw) are now distinguishable.** Use that: a throw means the capture failed, which is exactly the black-screen diagnostic the probe ticket wants.
- **There is no `Mode` parameter at all** — confirmed in the docs *and* in `functions.h:216`. v1's `Fast`, `RGB`, `Alt`, `Slow` are all gone; fast+RGB is now the only behaviour. **A v1 example ending in `, Fast RGB` will not just be ignored — it will be a parameter-count error.**
- `Variation` is unchanged: *"a number between 0 and 255 (inclusive)... allowed number of shades of variation."*
- Docs remarks worth knowing: the region **must be visible** ("it is not possible to retrieve the pixel color of a window hidden behind another window"); performance is better at 24/32-bit colour; search direction follows parameter order; large repeated searches burn CPU, so keep the rectangle small.

**`PixelGetColor`** — v2 signature, verbatim: `Color := PixelGetColor(X, Y [, Mode])`

- **Returns a string**, not a number: *"a hexadecimal numeric string representing the RGB (red-green-blue) color of the pixel."*
- **RGB, not BGR.** v1 defaulted to BGR. **A v1 colour literal copied into v2 will have red and blue swapped** — the single most likely silent miscopy in this whole project, since every colour constant in the pixel-signature ticket is affected.
- `Mode` accepts `Alt` and `Slow`, space-separated; *"Slow takes precedence over Alt."* Doc text for each: `Alt` — *"Uses an alternate method to retrieve the color, which should be used when the normal method produces invalid or inaccurate colors for a particular type of window. This method is about 10 % slower"*; `Slow` — *"Uses a more elaborate method to retrieve the color, which may work in certain full-screen applications when the other methods fail. This method is about three times slower."* **See §2.1 — the `Slow` description is a v1 leftover; in v2 it is the same BitBlt engine as `PixelSearch`.**
- Throws `OSError` on failure; no `ErrorLevel`.
- Remarks: partially transparent windows *"typically yield colors for the window behind"*; game cursors obstruct pixels beneath them (relevant — the reel bar sits near where a cursor may hover).

**`CoordMode`** — v2 signature: `PrevRelativeTo := CoordMode(TargetType [, RelativeTo])`

- `TargetType`: `"ToolTip"`, `"Pixel"` (affects `PixelGetColor`, `PixelSearch`, `ImageSearch`), `"Mouse"` (affects `MouseGetPos`, `Click`, `MouseMove`, `MouseClick`, `MouseClickDrag`), `"Caret"`, `"Menu"`. **Pixel and Mouse are separate settings — setting one does not set the other.**
- `RelativeTo`: `"Screen"` (desktop), `"Window"` (active window), `"Client"` (active window's client area, excluding title bar, standard menu and borders).
- **Two different "defaults", and confusing them is a real trap.** The docs say both: *"By default, coordinates are relative to the active window's client area"* — i.e. **`Client` is the mode in force before you ever call `CoordMode`** — and *"If omitted, it defaults to Screen"*, which is what the **`RelativeTo` argument** falls back to. So bare `CoordMode("Pixel")` sets **Screen**, while never calling it at all leaves **Client**. Confirmed by the changes page: *"CoordMode defaults to Client (added in v1.1.05) instead of Window."*
- **`"Relative"` was removed:** *"CoordMode no longer accepts 'Relative' as a mode, since all modes are relative to something. It was synonymous with 'Window', so use that instead."* A v1 script's `CoordMode, Pixel, Relative` **errors** in v2.

**`Click` / `MouseMove` / `MouseClickDrag`**

- `Click [Options]` — one string combining coords, `WhichButton`, `ClickCount`, `DownOrUp`, `Relative` in any order (ClickCount must follow the coords). `Click "100 200 R D"`.
- *"Unlike Send, the Click function does not automatically release the modifier keys."*
- `MouseMove X, Y [, Speed, Relative]`; `MouseClickDrag WhichButton, X1, Y1, X2, Y2 [, Speed, Relative]`. **`Speed` is ignored under `SendInput`/`SendPlay`** (movement is instantaneous) — only `SendEvent` honours it. Since `SendInput` is the v2 default, **a v1 example relying on a slow, human-looking mouse glide will teleport the cursor in v2.** Relevant if any mouse motion is ever wanted for its own sake.
- `[v2.0.7+]` `MouseClickDrag`'s `X1`/`Y1` may now be omitted; they were wrongly mandatory before. (Installed build is 2.0.18, so this applies.)

**`Send` and friends**

- `Send`, `SendText`, `SendEvent`, `SendInput`, `SendPlay` — all `Send Keys` shaped.
- **`SendMode` defaults to `Input` instead of `Event`** — verbatim from the changes page. This is the behaviour change most likely to bite when reading v1 macros: v1 defaulted to `SendEvent` with a 10 ms key delay, v2 sends with none.
- **`SetKeyDelay` has no effect under `SendInput`.** With `SendInput` now the default, `SetKeyDelay` in a pasted v1 script is silently inert. (`SendEvent` default: 10 ms delay, press-duration −1. `SendPlay`: both −1.) → §2.4.
- `{Blind}` must come first in the string. `{key down}` / `{key up}` and `{Enter}` are unchanged from v1.
- `SendMode(Mode)` where Mode ∈ `Event | Input | Play | InputThenPlay`.
- v2 change worth noting: *"Send (and its variants) now interpret {LButton} and {RButton} in a way consistent with hotkeys and Click. That is, LButton is the primary button and RButton is the secondary button, even if the user has swapped the buttons via system settings."*

**Everything else that makes a v1 example break silently rather than loudly** — the shortlist for the build ticket:

| v1 habit | What happens in v2 |
| --- | --- |
| BGR colour literals | **Wrong colours** (R and B swapped). Silent. |
| `if ErrorLevel` after a pixel call | **Dead branch.** `ErrorLevel` is never set by these functions. Silent. |
| `CoordMode, Pixel, Relative` | Errors loudly. |
| `PixelSearch ..., Fast RGB` | Parameter-count error. |
| Relying on default `SendEvent` pacing | Runs under `SendInput` with no delay. Silent. |
| `SetKeyDelay` with default send mode | Inert. Silent. |
| `MouseMove ..., Speed` for a human-looking glide | Instantaneous. Silent. |
| `FileDelete` on a missing file | **Throws** (v1 did not) — and an uncaught throw hangs on a dialog. POE2 hit this; see §1.3. |

---

# Strand 3 — Fisch specifics

## 3.1 The shake keyboard input — it exists, but it is NOT a Fisch setting

**This is the most consequential correction in this strand.** The map's standing decision reads *"Enter keypress via Fisch's keyboard/navigation shake setting"*. There is **no such setting in Fisch**. What players are actually using is a **Roblox platform-wide accessibility feature**.

- **The feature is Roblox's "Keyboard Navigation" / UI Selection toggle**, documented by Roblox itself (**Verified (primary source)**, `devforum.roblox.com/t/new-keybinds-for-keyboard-navigation/2069353`):
  > "The \\ (Backslash) key will now toggle UI Selection."

  and once toggled, *"use the arrow keys (▲▼◄►) or WASD to navigate between elements, and Enter to activate."* It is exposed in the Esc menu under **Controls → Misc**, labelled **"UI Selection Toggle"**, and is stated to be **on by default** for all players, in **any** experience that has not disabled automatic GUI selection.
- Corroborated by Roblox's own accessibility announcement (**Verified**, `devforum.roblox.com/t/introducing-accessibility-settings/2723187`): players can *"enable or disable the shortcut for Keyboard Navigation"*, present in *"both the in-experience menu settings, as well as app settings."*
- **The working flow is: press `\` → arrow keys move the highlight onto the SHAKE button → `Enter` activates it.** The `\`-then-`Enter` sequence is **Likely** (a single secondary guide, `gamertweak.com/fish-without-shake-in-roblox-fisch/`, but its mechanism matches the Verified Roblox keybind docs exactly).
- Roblox **auto-activates** this navigation mode when it detects a gamepad. It is **not** mobile- or console-only; it is a PC keyboard/gamepad accessibility feature. **Verified.**
- **The one genuinely Fisch-side shake setting that does exist** is different: **"Allow Shake Button Misclicking"**, added in v1.89.0, **enabled by default**, described as *"prevents the Shaking minigame from being cancelled if you misclick"* (`fisch.fandom.com/wiki/Changelogs` via reader proxy — **Likely**, fan-wiki changelog transcription).

**What this changes for the map**, without reopening the decision: the SHAKE-via-keypress decision **survives** — Enter really can clear the shake without clicking. But the mechanism is not what the map says, and three things follow that [issues/02-shake-via-keypress.md](../issues/02-shake-via-keypress.md) must confirm live:

1. **There may be a `\` prerequisite.** Enter alone likely does nothing until UI Selection is toggled on. If so, the script's start-up sequence needs it (or the user enables it once by hand), and a lost toggle is a silent failure mode.
2. **Enter activates *whatever the highlight is on*.** That is a shared, stateful cursor, not a dedicated shake key. If the highlight lands on some other button, Enter presses that instead. This is a materially different risk profile from a dedicated keybind and worth watching for during tuning.
3. **The map's own fog item "Does `bait` need positive detection at all"** leans harder toward *yes* under this mechanism, since blind Enter-tapping on a cadence could activate unintended UI.

Also note: because this is a Roblox-level feature rather than a Fisch feature, the "Hunting the SHAKE circle visually" fallback the map ruled out stays genuinely available if the navigation route disappoints.

## 3.2 The reel minigame's colour change — no documentation either way

**Not found.** No source documents the player-controlled zone changing colour based on whether the fish is inside it. Every source consistently describes it only as the **"white bar" / "white slider" / "control bar"**, with no mention of tan, brown, or any state-dependent colour. Searched specifically for colour, "turns tan", "turns brown", and changelog entries about visual updates.

**This is an absence of documentation, not a refutation.** The map's observation was lifted from the user's own two screenshots (`fish_on.png` vs `fish_on2.png`), which is *stronger* evidence than a wiki silence. Undocumented cosmetic details are entirely normal. Treat [issues/05-reel-steering-strategy.md](../issues/05-reel-steering-strategy.md) as the place this gets settled, and note the research did not find anything to contradict it.

One tangential lead, flagged because it could confound a screenshot comparison: TikTok content titled *"How to Change Control Bar Colors on Fisch"* suggests a **player-chosen cosmetic bar colour** may exist. **Unverified** (title only; TikTok bodies not accessible). If real, it means the observed colours are a user setting and calibration must capture them rather than hard-code them — which the map's point-and-capture picker already handles.

**What *is* documented about the bar** (all from `fisch.fandom.com` read via reader proxy, cross-corroborated by search snippets attributed to the official `fischipedia.org` — **Likely**, since the official wiki itself was CAPTCHA-blocked):

- **Movement:** the bar drifts **left** on its own; **holding Space, holding left-click, or press-and-hold on touch** accelerates it **right**; releasing lets it drift back left. **This is a hold-and-release control, not a click-to-move one** — directly relevant to how steering must be implemented.
- **Progress:** gained or lost at **12% per second** depending on whether the fish is inside or outside the bar. Symmetric, which means the binary on-target read the map hopes for is sufficient in principle — you only need to know which sign you are on.
- **Failure:** at 0% progress *"their line snaps and they lose the fish as well as any fishing streak."*
- **Zone width is a rod stat:** the rod's **Control** stat sets bar width — **0 Control = 30%** of the minigame UI width, each **+0.01 Control = +1% width**, **capped at +0.7 Control = 70%**. So the player zone's width varies by equipped rod (and some fish abilities shrink it). **A calibration that hard-codes the zone width will break on a rod change.**
- **Resilience** (a separate stat/fish property) affects how erratically the fish marker moves and the bar's speed.

## 3.3 The cast power meter — still fog, but the "perfect cast" payoff is now known

**Screen-anchored vs world-space billboard: Not found.** No source uses "BillboardGui" in connection with Fisch's cast meter, and none states whether the meter's screen position changes with the camera. This map fog item **survives the research unresolved** and must be settled empirically.

The evidence that exists is genuinely ambiguous, and worth understanding so it is not over-read. Multiple independent secondary sources (Fisch wiki via proxy, plus several guide sites) describe it in near-identical words — *"a bar appears next to your character"* / *"on the side of the character"* / *"to the right of the player"* (**Likely**). That matches the map's own observation from `casting.png` that the meter sits beside the character rather than centred. **But it is not evidence of world-anchoring:** because Fisch's camera keeps the character roughly centred, a plain fixed-position `ScreenGui` bar would *also* read as "next to your character" to every guide writer. The phrasing cannot distinguish the two cases.

**The decisive test is the obvious one and takes seconds:** start a cast, move the camera, and see whether the bar's screen coordinates move. That belongs in [issues/04-status-pixel-signatures.md](../issues/04-status-pixel-signatures.md), where the map already parks it.

**Documented cast mechanics** (**Likely** unless noted):

- **Trigger:** hold **left-click** on PC (R2 on PlayStation, tap-and-hold on mobile) with a rod equipped; releasing throws the bobber. Confirms the map's "fixed hold time" plain-cast approach is mechanically right, and see §2.4 — it must be an explicit `{LButton down}` / `Sleep` / `{LButton up}`.
- **Perfect cast condition**, near-verbatim from `fisch.fandom.com/wiki/Casting`: achieved *"only when the white [power] bar is inside the tiny green overlay at the top of the bar"*. This **matches the map's screenshot observation exactly** — a green tick at the top edge of the meter (y≈450–462), with the meter spanning y≈455–690. Independent confirmation that the map read the right thing off `casting.png`.
- **A distinct "click" sound plays on a perfect cast.** Noted because it is a non-visual signal, if audio were ever easier than pixels (it is not, in AHK).
- **The payoff is small.** From the same page: *"A 'perfect cast' is the maximum the rod line length can be increased, but does not do anything else"* — it maximises cast distance/line length only. **It does not improve catch rate, rarity, or anything else.**

**Bearing on a standing decision:** the map already marks perfect cast as *"droppable if the meter proves unreadable"*. This finding strengthens that considerably — the feature buys **cast distance only**, so if the meter turns out to be camera-anchored, dropping it costs the user almost nothing. Worth telling the user in those terms before any effort is spent on a search band.

## 3.4 Anti-macro detection — the developer says the opposite of the map's premise

**Roblox's official policy, Verified first-hand.** Two findings, one of which corrects a widely repeated claim:

- **The current Roblox Terms of Use never uses the words "macro", "bot", "automat", or "autoclick".** The live document (`en.help.roblox.com/hc/en-us/articles/115004647846-Roblox-Terms-of-Use`) was fetched and searched for each term; "third-party" appears only in unrelated Robux/advertising clauses. **The frequently quoted line *"Using any automated system, including 'bots' or 'macros', to interact with the Service is prohibited"* could not be found in it** — treat that quote as **Unverified / likely a secondary-blog paraphrase**, not ToU text.
- **The automation language actually lives in the Community Standards** (`about.roblox.com/community-standards`, fetched directly — **Verified**):
  - Integrity → Cheating and Scams: *"Roblox doesn't allow cheating, exploits, or misleading content or schemes, including: … Using or sharing exploits to help yourself or others gain an unfair advantage anywhere on the platform"*
  - Security → Misusing Roblox Systems: *"Using bots or other automation that is programmed to run **disruptive** tasks"*
  - **Note the qualifier.** It is not a blanket ban on automation, only on *disruptive* automation. Roblox Support's "Cheating and Exploiting" page separately says cheating/exploiting *"is a violation of the Roblox Terms of Use, and will lead to the deletion of an account"* (**Verified**) but likewise never defines "macro".

**Fisch's developers say macro detection is infeasible — and they allow use.** From the official Fisch developer account **@FischOnROBLOX**, 2024-12-17, replying to a player asking about macro detection:

> "It is unfeasible to detect players using macros. We'd be making the moderation team's lives a living hell by banning the use of it, which is why the use of it is allowed, but not the distribution of it. This isn't something we can prevent by any means, as ROBLOX does not have a [feature to detect things like these, even through heatmapping]."

`x.com/FischOnROBLOX/status/1869047173997895831` — **Likely**, not Verified: `x.com` returned 402/403 on every fetch, direct and proxied, so this is reconstructed from two independent search queries whose cached snippets matched wording and attribution. The bracketed tail is reconstructed and should not be treated as literal.

**This directly contradicts the map's stated premise.** The map's Timing row reads *"Jittered by a few dozen ms. Automating Roblox breaches its terms and Fisch watches for robotic regularity; the user was told and chose jitter."* Both halves need adjusting:

- **"Fisch watches for robotic regularity"** — **no source states this, and the one developer statement found says detection is "unfeasible" and that macro *use* is allowed while *distribution* is the bannable act.** Nothing anywhere describes input-timing regularity as a flagged signal. That specific claim is **Not found, and contradicted by the best available source.**
- **"Automating Roblox breaches its terms"** — **overstated as written.** The ToU does not mention macros at all; the Community Standards ban *disruptive* automation and *exploits*. A local input-simulation macro that injects no code sits in a genuine grey area under Roblox's own wording. (That reading is **Likely** — it is inference from the Verified clauses, not a sentence Roblox wrote.)

**This is not an argument to remove the jitter.** Jitter is cheap, harmless, and hedges against exactly the kind of undisclosed heuristic no one can rule out — and Roblox does not publish what Hyperion looks at (§2.6). But the *justification* on the map is factually wrong, and the user was told something ("Fisch watches for robotic regularity") that no source supports. They deserve the correction, since it was presented to them as a reason for a decision. The honest framing is: *nobody has documented timing-based detection; the developers say they cannot detect macros and tolerate their use; jitter stays because it is nearly free insurance, not because a known detector requires it.*

**Anti-macro-adjacent features that are documented** (none framed by the developers as anti-cheat):

- **The SHAKE button spawns at a randomised on-screen position each time** — confirmed by multiple sources including a Roblox DevForum thread reverse-engineering the system (`devforum.roblox.com/t/how-to-make-the-fisch-shake-system/3495513`). **Likely.** This incidentally defeats fixed-coordinate autoclickers, but reads as core gameplay design, not an anti-macro measure. **It also independently corroborates the map's screenshot-derived suspicion that the SHAKE circle roams** — and it is a further point in favour of the keypress route over visual hunting.
- **Fisch has an AFK Mine that auto-rejoins a server every 15 minutes specifically to survive Roblox's platform-wide ~20-minute AFK disconnect** (`fischipedia.org` "AFK Rewards", **Likely**, snippet-sourced). This is a developer-built **AFK-friendly** feature — the opposite of an anti-AFK check. Mildly relevant to the map's out-of-scope "surviving the idle kick" item: the game itself is not hostile to idling.
- **No Fisch-specific "are you there" prompt, in-game captcha, or anti-macro UI randomisation was found. Not found.**
- **Community ban reports are contradictory and Unverified.** Some players claim macroing is not bannable; others claim bans while macroing. No official incident report, ban-reason confirmation, or developer acknowledgment ties any specific ban to macro *use* as opposed to *distribution* or unrelated exploiting.

---

## Open items this research could not close

| Item | Why it stayed open | Where it should be settled |
| --- | --- | --- |
| Do pixel reads actually work against Roblox? | No verified first-hand report either way; AHK forums Cloudflare-blocked. Mechanism says "probably yes in windowed/borderless" but that is inference. | [01-can-ahk-see-roblox-pixels.md](../issues/01-can-ahk-see-roblox-pixels.md) — test `PixelSearch`, `PixelGetColor`, and `PixelGetColor "Alt"` separately (§2.1). |
| Is `RobloxPlayerBeta.exe` elevated? | Not documented anywhere. | Trivial to check live; decides whether the UIA build matters at all. |
| Is the cast meter screen- or world-anchored? | No source addresses it; the "next to your character" phrasing cannot distinguish the two. | [04-status-pixel-signatures.md](../issues/04-status-pixel-signatures.md) — move the camera mid-cast. |
| Does the reel zone change colour on-target? | Undocumented; the user's screenshots are better evidence than the wiki's silence. | [05-reel-steering-strategy.md](../issues/05-reel-steering-strategy.md). |
| Does Enter-for-shake need `\` pressed first? | The Roblox docs establish the toggle exists and defaults on; whether Fisch's SHAKE button needs an explicit toggle + highlight was not documented. | [02-shake-via-keypress.md](../issues/02-shake-via-keypress.md). |
| Does Hyperion react to synthetic input? | Not documented, officially or otherwise. | Unresolvable by research. |

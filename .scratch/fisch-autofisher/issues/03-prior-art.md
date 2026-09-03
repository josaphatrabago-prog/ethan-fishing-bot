# Prior art: Fisch macros, the old POE2 AHK notes, and Roblox pixel reading

Type: research
Status: resolved
Blocked by: —
Parent: ../map.md
Label: `wayfinder:research`

AFK — resolved by a `/research` subagent. Findings land at `findings/03-prior-art.md`
under this effort (this repo is not a git repo, so there is no `research/<name>` branch).

## Question

What is already known — by this user, and publicly — that would stop us rediscovering it
the hard way? Three separate strands:

### 1. The user's own earlier AHK work

The Obsidian vault's **POE2** project folder contains notes mentioning AutoHotkey, AHK,
PixelSearch and Roblox across its `Status.md`, `Bugs.md`, `Pitfalls.md` and
`Architecture.md`. Read them and extract anything that transfers:

- Pitfalls already hit with `PixelSearch` (tolerance values, DirectX capture problems,
  timing, coordinate modes)
- Whether AHK v1 or v2 was used there, and why
- Any GUI patterns already built and liked
- Any conclusion about whether pixel reads worked against a hardware-accelerated game

This is the highest-value strand: it is the user's own hard-won experience, and it is
already written down.

### 2. Reading pixels out of Roblox from AutoHotkey v2

Establish the current state of fact, from primary or high-trust sources:

- Does `PixelGetColor` / `PixelSearch` work against the Roblox client, and in which window
  modes? What is the known failure mode?
- Does `PixelSearch` need an alternate capture flag or approach on DX11 surfaces?
- Does Roblox accept AHK-synthesised mouse and keyboard input, and is the UIA build needed?
- The v1 → v2 syntax differences for `PixelSearch`, `PixelGetColor`, `CoordMode`, `Click`
  and `Send` — enough to safely read v1 examples without miscopying them.

### 3. Fisch specifics

- Does Fisch have a documented shake input setting with a keyboard option, and what is it
  called? (Cross-checks
  [Answer SHAKE with a keypress](02-shake-via-keypress.md), which confirms it live.)
- Is the reel minigame's player zone documented as changing colour when the fish is inside
  versus outside it? (Cross-checks the key simplification in
  [How the reel minigame gets steered](05-reel-steering-strategy.md).)
- Is the cast power meter screen-anchored UI or a world-space billboard on the rod? (This
  is the open fog item on the map.)
- What is publicly known about Fisch's or Roblox's anti-macro detection — specifically
  whether input-timing regularity is actually what gets flagged. The user has already
  chosen jittered timing; this is to check the reasoning holds, not to reopen it.

## Constraints

- Prefer primary sources: AutoHotkey v2 official docs, Roblox developer docs, the Fisch
  wiki. Flag anything that is only a forum claim as exactly that.
- Do **not** write any script here. This ticket produces findings, not code.
- Do **not** reopen settled decisions on the map — report facts that bear on them and let
  the map owner decide.

## Answer

Full findings, with a source and confidence level per claim:
**[findings/03-prior-art.md](../findings/03-prior-art.md)**

Access note: `autohotkey.com` is Cloudflare-blocked here (HTTP 403), docs *and* forums, so **no
AutoHotkey forum thread could be read** — every AHK-forum claim is Unverified. Official doc text
was read instead from the `AutoHotkeyDocs` GitHub source (same text the site renders), and better
still, the **v2.0.18 C++ source** — the exact installed build — was downloaded and grepped, which
settles two questions the docs leave ambiguous. `x.com` and `fischipedia.org` (the *official* Fisch
wiki) were blocked; `fisch.fandom.com` was readable only via a reader proxy.

### 1. The POE2 notes — rich on AHK craft, silent on Roblox

POE2 is **Path of Exile 2**, not Roblox, and it is the **only** project in the vault with any AHK
content. It **does not answer** the four questions that mattered most: no DirectX/hardware-
acceleration lesson, no black-screen or capture-failure note, no window-mode requirement, no
anti-cheat conclusion. **So prior art does not de-risk "can PixelSearch see Roblox" —
[01](01-can-ahk-see-roblox-pixels.md) stays a real first step.** It also never used `PixelSearch`
at all (single-point `PixelGetColor` + `ColorDist` for globes, `ImageSearch` for icons), so there
is no PixelSearch tolerance number to inherit.

What *does* transfer, and it is worth a lot:

- **AHK v2 confirmed** (v2-only was a hard requirement), and `AutoHotkey64.exe /validate` is the
  user's established pre-flight gate — adopt it for [11](11-build-the-script.md).
- **The recurring bug that cost three sessions** (Pitfalls #9): every control assigned inside a
  GUI-builder function must be in that function's `global` list, or the control renders fine and a
  *different* function throws `""` has no property later. Plus: buttons have no `.Value` (use
  `.Text`), `Add("ListBox",…,"")` throws (pass `[]`), a ListBox `.Value` loses its selection when a
  button takes focus, and **`FileDelete` throws in v2 on a missing file** — an uncaught throw hangs
  the script on a dialog. All aimed straight at [09](09-control-window.md) and
  [10](10-settings-and-proportional-coords.md).
- **A GUI shape already built and liked twice:** calibration wizard on a hotkey, tuning sliders, a
  **log area** (leaned on repeatedly for live diagnosis), **F9 start/stop with F12 as a separate
  emergency exit**, INI config beside the script, and a picker with a live preview.
- **Every tolerance the user shipped became a live slider, not a constant** — twice a hard-coded
  default was wrong and the fix was to expose it. Independent support for the map's tuning-sliders
  decision. Both abandoned approaches (stdev occupancy, dHash dedup) died the same way: a threshold
  tuned on a clean sample collapsed against a busy animated background — so **prefer structurally
  stable discriminators over lucky thresholds** (bears on the day/night-lighting fog and [04](04-status-pixel-signatures.md)).
- **UI elements move** (Pitfalls #1/#12): PoE2's buff row *slid*, and a 3px anchor error dropped
  detection from 8/8 to 2/8. The fix was *search a band, don't probe a point* — the same fallback
  [07](07-perfect-cast-readable.md) contemplates.
- Elevation in POE2 was needed **only** for AutoHotInterception's kernel driver, not for pixel
  reading. No such driver here.

### 2. Roblox pixel reading and AHK v2

- **The four capture paths, read out of the installed v2.0.18 source** (not just the docs):
  `PixelSearch` (its only mode) = `GetDC(NULL)`+`BitBlt`+`GetDIBits`; plain `PixelGetColor` =
  `GetDC(NULL)`+`GetPixel`; `"Alt"` = `CreateDC("DISPLAY")`+`GetPixel`; **`"Slow"` delegates to a
  1×1 `PixelSearch`**, i.e. the same BitBlt engine. All three modes are really implemented. Two
  consequences: the docs' promise that `"Slow"` "may work in certain full-screen applications when
  the other methods fail" is a **stale v1 leftover** — it is not an independent fallback; and
  **`"Alt"` is the only genuinely different capture path**. So [01](01-can-ahk-see-roblox-pixels.md)
  should probe **three** calls, not one, or risk a false negative.
- **The black-screen mechanism is compositor bypass, not DirectX.** AHK's own changes page:
  *"PixelSearch's slow mode was removed, as it is unusable on most modern systems due to an
  incompatibility with desktop composition."* Windowed and borderless go through DWM and read fine;
  only **true exclusive fullscreen** bypasses it. And **Roblox appears to have no true exclusive
  fullscreen left** — its "Fullscreen"/F11 is borderless windowed (Roblox DevForum, community
  author, Likely). Renderer is **D3D11** (Verified, `create.roblox.com`). **DX11 alone does not
  break GDI reads** — so pixel reads are *likely* to work, though no verified first-hand
  Roblox+PixelSearch report was obtainable either way. Probe windowed first.
- **⚠ The `CoordMode` footgun — bears on a standing map decision.** Verified in `util.cpp`:
  `CoordToScreen` uses **`GetForegroundWindow()`**, so `"Window"`/`"Client"` pixel coords are
  relative to **whatever window is foreground, not to Roblox**. Alt-tab away and reads silently
  re-anchor; **clicking the script's own control GUI makes *it* foreground and breaks reads while
  tuning**; and if the foreground window is minimized it silently falls back to screen coords.
  No error in any case. The focus-independent alternative is
  `WinGetClientPos …, "ahk_exe RobloxPlayerBeta.exe"` + `CoordMode "Pixel","Screen"`, which also
  composes with proportional coords and handles negative Y by *reading* an origin instead of
  assuming one. Note too that the negative-Y problem `"Window"` was chosen to avoid **does not
  arise** while Roblox sits on the primary 1920×1080 `DISPLAY3`. If `"Window"` is kept, prefer
  **`"Client"`** (already v2's default) — it excludes the title bar, so coords survive a
  windowed↔borderless switch.
- **Elevation/UIA almost certainly unnecessary.** The UIA build solves exactly one problem —
  automating an *elevated* target from a non-elevated script (Verified, FAQ + `Send` docs on UIPI).
  Whether Roblox is elevated is **undocumented**, but nothing here forces admin. **Focus, however,
  is required**: `Send` targets the *active* window by design, and per the above so do
  window-relative pixel reads. So "unattended" realistically means *"runs while you leave the PC
  alone"*, closing most of that map fog item.
- **v1→v2 traps that fail *silently***: v1 colour literals are **BGR** and v2 is **RGB** (red/blue
  swapped — the likeliest miscopy in this whole project, since every colour constant in
  [04](04-status-pixel-signatures.md) is affected); `ErrorLevel` branches after pixel calls are dead
  code (v2 returns 1/0 and **throws `OSError` on a real failure** — usefully, that distinguishes
  "not found" from "couldn't capture"); `SendMode` **defaults to `Input`** in v2, and
  **`SetKeyDelay` is inert under `SendInput`**; `MouseMove`'s `Speed` is ignored under `SendInput`.
  Loud failures: `PixelSearch` has **no `Mode` parameter at all** in v2 (`Fast RGB` = arg-count
  error) and `CoordMode … Relative` was removed.
- **Consequence for the cast:** "fixed hold time" must be explicit
  `{LButton down}` → `Sleep` → `{LButton up}`, not a delay setting — which is also the official
  FAQ's documented remedy when a game drops keystrokes.
- **Hyperion/Byfron:** acquisition Verified from Roblox's own SEC 10-Q; what it *does* is published
  nowhere — the "anti-injection only" characterisation is community analysis (Unverified), and
  whether it reacts to synthetic input is **Not found**. Do not rely on either way.

### 3. Fisch's own mechanics and its anti-macro posture

- **⚠ The shake keyboard input exists, but it is NOT a Fisch setting.** It is Roblox's
  platform-wide **"UI Selection Toggle" / Keyboard Navigation** accessibility feature (Verified,
  two official Roblox DevForum posts): *"The \\ (Backslash) key will now toggle UI Selection"*, then
  arrows/WASD to move the highlight and **Enter to activate**. Lives in Esc → Controls → Misc,
  **on by default**, works in any experience. **The decision survives — Enter really can clear the
  shake — but the mechanism differs from the map's wording**, and [02](02-shake-via-keypress.md)
  must confirm live that (a) `\` is a prerequisite the script may need to press, and (b) Enter
  activates *whatever the highlight is on* — a shared stateful cursor, not a dedicated shake key,
  which nudges the "does `bait` need positive detection" fog toward **yes**. (The one real
  Fisch-side setting is different: **"Allow Shake Button Misclicking"**, default on.) Separately,
  the **randomised SHAKE-button position is independently confirmed**, corroborating the map's
  screenshot-derived suspicion that the circle roams.
- **Reel zone colour change: Not found** — no documentation either way; sources only ever call it
  the "white bar". That is wiki *silence*, not a refutation, and the user's own two screenshots are
  better evidence, so [05](05-reel-steering-strategy.md) still owns it. Nothing contradicts it. What
  *is* documented and matters: the bar drifts **left** on its own and **holding** Space/left-click
  drives it right (a hold-release control, not click-to-move); progress moves ±**12%/sec** —
  symmetric, so a binary on-target read is sufficient in principle; at 0% the line snaps and the
  streak is lost; and **the zone's width is set by the rod's Control stat** (30% at 0, +1% per
  +0.01, capped 70%) — so **never hard-code the zone width; a rod change breaks it**. One
  Unverified lead: bar colour may be a *player-chosen cosmetic*, which would mean calibration must
  capture it (the picker already does).
- **Cast meter anchoring: Not found — the fog item survives.** The much-repeated "a bar appears next
  to your character" phrasing **cannot distinguish** the two cases, because Fisch's camera keeps the
  character centred, so a fixed `ScreenGui` bar would read the same way. Settle it in
  [04](04-status-pixel-signatures.md) by moving the camera mid-cast. Two useful confirmations
  though: the perfect-cast condition is *"only when the white bar is inside the tiny green overlay
  at the top of the bar"* — **exactly matching the green tick the map read off `casting.png`** — and
  **the payoff is cast distance only**: *"a 'perfect cast' is the maximum the rod line length can be
  increased, but does not do anything else"*. No catch-rate or rarity benefit, which makes the map's
  "droppable" call much easier and worth telling the user in those terms.
- **⚠ Anti-macro: the map's premise is contradicted.** The map says *"Fisch watches for robotic
  regularity"* — **no source states this**, and the official **@FischOnROBLOX** developer account
  (2024-12-17, Likely — `x.com` blocked, reconstructed from matching cached snippets) says the
  opposite: *"It is unfeasible to detect players using macros… which is why the use of it is
  allowed, but not the distribution of it… ROBLOX does not have a [feature to detect things like
  these]."* Input-timing regularity as a flagged signal is **Not found and contradicted**. Also
  **"automating Roblox breaches its terms" is overstated**: the live ToU was fetched and searched —
  it never uses "macro", "bot", "automat" or "autoclick", and the widely quoted "bots or macros"
  ToU line **is not in it**. The Community Standards ban *exploits* and only ***disruptive***
  automation (Verified). **This is not a reason to drop the jitter** — it is cheap insurance against
  undisclosed heuristics, and Roblox publishes nothing about what Hyperion inspects — but the
  *justification* given to the user was wrong and they should get the correction. Related: Fisch's
  **AFK Mine auto-rejoins every 15 min** to beat Roblox's ~20-min idle kick, i.e. the game is
  AFK-*friendly*; and **no captcha or "are you there" check was found**.

# Map: Fisch Auto-Fisher (AutoHotkey + PixelSearch)

Label: `wayfinder:map`

## Destination

A runnable AutoHotkey v2 auto-fisher for the Roblox game **Fisch**: one `.ahk` script plus
its control window that gets double-clicked and then runs the cast -> shake -> reel ->
success loop indefinitely on this machine. Done means it actually catches fish unattended,
with live counters, live tuning sliders, and point-and-capture recalibration of both the
colours and the coordinates it watches.

## Notes

**This map carries execution, not just decisions.** The destination is a working script, so
the final tickets build and tune it. Everything before them is still decide-first.

**Domain.** Roblox "Fisch" fishing minigame automation via screen-pixel reading. The
`Status` vocabulary is the user's own and matches `screenshots/`:
`idle` / `casting` / `bait` / `fish_on` / `success`.

**Core design, settled while charting** (the user's own framing, adopted):

- One `Status` is read from pixels each tick; the `Status` decides the next action.
- `idle` is the **fall-through**, never positively detected. The script positively looks for
  `casting`, `bait`, `fish_on` and `success`; anything matching none of those *is* `idle`,
  so it casts. There is therefore no "unknown state" to get confused by.

**Standing decisions from charting.** These are premises, not route steps -- they were set
before any ticket existed, so they live here rather than in Decisions so far:

| Decision | Answer |
| --- | --- |
| Scope | Catch loop only. Never touches inventory, never walks, never sells. |
| SHAKE input | **Enter keypress — the original decision, and it is what shipped.** Research claimed Enter could only work via Roblox's `\` UI Selection Toggle and would be unreliable because that highlight is shared; on the strength of that the decision was reversed to ring-clicking, then reversed back when the user said plainly that Enter just works. **It does:** no toggle, no chat box, and slightly better than clicking (2.42 vs 2.15 hooks/min). The research inference was drawn from an absence of documentation and was simply wrong. See [ticket 02](issues/02-shake-via-keypress.md). |
| Plain cast | Fixed hold time, built first so the loop runs end to end early. |
| Perfect cast | **OUT OF SCOPE as of 2026-09-03.** Chosen as a droppable toggle at charting, then dropped once research established it grants line **distance only** — no catch-rate or rarity benefit — which is worth nothing to a loop that fishes from one fixed spot. See Out of scope. |
| Reel precision | Start with the simplest strategy that holds a fish; escalate only if catch rate is bad. Research supports this: catch progress is symmetric at roughly ±12%/sec, so the steering only has to be net-positive, not perfect. |
| Coordinates | Stored as proportions of the game window, so monitor/resolution changes mostly survive. |
| Calibration | Point-and-capture picker for **both** colour and coordinate; persisted to a settings file. |
| Control window | Start/stop + hotkey, live `Status`, counters, live tuning sliders, calibration panel. |
| Timing | Jittered by a few dozen ms. **The justification given at charting was wrong** and the user was told a wrong reason -- Roblox's live Terms never mention macros or automation, and Fisch's own dev account states macro *use* is allowed while *distribution* is not. No source supports timing-regularity detection. The decision stands anyway, as cheap insurance against undisclosed heuristics. Correction detail in [Prior art](issues/03-prior-art.md). |
| Stuck handling | No watchdog auto-stop. User states cast always leads to shake always leads to `fish_on`. The counters make a stall visible instead ("casts climbing, catches flat"). |

**Environment facts, already looked up -- do not re-derive:**

- AutoHotkey **v1.1.37.02 and v2.0.18** both installed under `C:\Program Files\AutoHotkey\`.
  v2.0.18 is the registered default (`HKLM:\SOFTWARE\AutoHotkey`). **Target v2.**
  Most Roblox macros found online are v1 syntax -- do not paste them in unconverted.
- Three monitors: primary `DISPLAY3` 1920x1080 at (0,0); `DISPLAY1` 2560x1440 at
  (1920,-181); `DISPLAY2` 1920x1080 at (4480,9). The **negative Y** on DISPLAY1 means
  desktop screen coordinates are not 0-based.
- **Coordinate mode -- CORRECTED, this map originally had it wrong.** Do **not** use
  `CoordMode "Pixel", "Window"`. AHK's window/client coordinate modes resolve against
  `GetForegroundWindow()`, i.e. whatever window is foreground -- *not* against Roblox. Three
  silent failure modes follow, with no exception and no error: alt-tabbing re-anchors every
  read to the new foreground window; **clicking the script's own control GUI makes the GUI
  foreground and breaks every pixel read while the user is tuning**; and a minimized
  foreground window silently falls back to screen coordinates. Since a control GUI is a core
  deliverable here, this is disqualifying. **Use instead:** `CoordMode "Pixel", "Screen"`
  plus `WinGetClientPos &x, &y, &w, &h, "ahk_exe RobloxPlayerBeta.exe"`, then
  `proportion * clientSize + clientOrigin`. That is focus-independent, GUI-safe, composes
  with the proportional-coordinate decision, and handles negative Y correctly because it
  reads the origin rather than assuming one. Evidence in [Prior art](issues/03-prior-art.md).
- **Which pixel call to probe.** The three AHK v2 pixel calls take *different capture paths*,
  so testing only one risks a false negative: `PixelSearch` uses BitBlt + GetDIBits; plain
  `PixelGetColor` uses GetPixel; `PixelGetColor` with **`"Alt"`** uses
  `CreateDC("DISPLAY")` + GetPixel and is **the only genuinely different path**. The docs'
  claim that `"Slow"` helps in full-screen apps is a stale v1 leftover -- in v2.0.18 `"Slow"`
  just delegates to a 1x1 `PixelSearch`.
- **The black-screen failure is compositor bypass, not DirectX.** Only *true exclusive
  fullscreen* bypasses DWM, and Roblox appears to have no true exclusive fullscreen left
  (F11 is borderless). So D3D11 alone does not break GDI reads, and PixelSearch against
  Roblox is *probably* fine -- but no verified first-hand report was found either way, so
  [ticket 01](issues/01-can-ahk-see-roblox-pixels.md) still stands as the first step.
- **Colour literals are red/blue swapped between v1 and v2.** v1 pixel colours were BGR;
  v2 is RGB. Every colour constant copied from a v1 example is wrong, and it fails
  **silently**. Related v2 deltas: `ErrorLevel` branches are dead code (v2 throws `OSError`
  on capture failure -- which usefully distinguishes "colour not found" from "could not
  see the screen"), `SendMode` now defaults to `Input`, and **`SetKeyDelay` is inert under
  `SendInput`**.
- **Input needs focus; elevation does not.** The UIA build solves exactly one problem
  (automating an *elevated* target) and is almost certainly unnecessary. But `Send` targets
  the active window by design, so Roblox must be foreground for input to land. "Unattended"
  therefore means *leave the PC alone*, not *alt-tab and do something else*.
- **Reads need Roblox VISIBLE, not merely focused — a correction to how ticket 01 phrased
  it.** Screen-mode reads are genuinely focus-independent, but they read *the screen*: when
  another window came to the front and covered Roblox during a live run, every probe happily
  returned that window's pixels instead, with no error. Ticket 01's own GUI test only stayed
  valid because the test window was small and parked away from the probe point. Practical
  upshot is unchanged (Roblox must be foreground anyway, for input), but the failure mode to
  guard against is **occlusion**, and the script should verify Roblox is actually the
  foreground window before trusting a reading.
- **`AutoHotInterception` is available as an input fallback** if `SendInput` ever proves
  insufficient — a driver-level input library the user pointed to:
  <https://github.com/evilC/AutoHotInterception>. **Not currently needed**: plain `SendInput`
  was verified to reach the game for both mouse and keyboard. Keep it in reserve rather than
  adopting it, since it requires installing a driver.
- **Signatures must be structural, not colour-matched.** The hard-won rule from the live
  verification: a good detector asks *"is a bright UI element rendered inside this small fixed
  box?"*, which survives lighting and camera changes. A bad detector matches an absolute
  colour at a point where scenery or the player model can appear — every one of those failed
  live. Scenery-backed points swung across max-channel 17..135 and 19..255 in a single run.
- **Pre-flight gate -- CORRECTED 2026-09-03.** The POE2 notes recommend
  `AutoHotkey64.exe /validate`, and this map adopted it. **It does not work here:** tested
  against a known-good and a known-bad script, it returns **exit code 2 for both** and
  prints nothing, with or without `/ErrorStdOut`. Worse, **a syntax error puts AutoHotkey
  on a modal dialog and hangs it forever** — reproduced twice, and `/ErrorStdOut` does not
  suppress it. **Use instead:** launch via `Start-Process -PassThru` +
  `WaitForExit(<ms>)` + `Kill()` on timeout; a script still alive past its expected runtime
  has a parse error. Never invoke AHK from a plain shell call with no timeout.
- **Do not target Roblox by `ahk_exe` alone.** Verified live: `RobloxPlayerBeta.exe` can be
  running with **zero visible windows** — only hidden `SystrayIcon` and `IME` stubs — when
  no game is open, so `WinExist("ahk_exe RobloxPlayerBeta.exe")` returns nothing while the
  process is very much alive. Find the largest **visible** window owned by a process whose
  name contains "Roblox", with an area gate (~300k px) to reject the stubs. Without this the
  script silently does nothing whenever Roblox sits at the launcher or in the tray.
- **AHK v2 `Format` silently ignores invalid format flags.** Bare `{}` works, and so do
  `{:06X}` and `{:.3f}`, but **`{:<10}` is invalid** — `<`/`>` alignment is Python/.NET, not
  AHK — and the placeholder is emitted **literally, with no error**. Use printf style:
  `{1:-10}` left-aligns, `{1:10}` right-aligns. This silently corrupted a whole diagnostic
  report before it was noticed.
- **A full-screen overlay is running:** `NVIDIA Overlay.exe`, class `CEF-OSC-WIDGET`,
  visible at 1920x1080. A transparent window sitting over Roblox is a plausible confounder
  for screen capture — if pixel reads come back wrong, disable it and re-test first.
- `screenshots/*.png` are all 1920x1080, so captured on a 1080p screen. They are the
  ground truth for state signatures. Reference resolution = **1920x1080**.
- **Display mode settled 2026-09-03: borderless fullscreen (F11).** Measured live — client
  becomes exactly **1920x1080 at (0,0) with zero chrome** (dx=0, dy=0), matching
  `screenshots/` pixel for pixel. Maximized-windowed was also tested and reads fine, but
  gives a **1920x1017** client with 31px of title bar and a **1.8879 aspect (not 16:9)**,
  which makes the reference screenshots unusable. Fullscreen is therefore a documented
  prerequisite, and it defuses ticket 10's aspect-ratio worry for the normal case.
- **Roblox window identity, confirmed live:** `ahk_exe RobloxPlayerBeta.exe`, class
  **`WINDOWSCLIENT`**, title `Roblox`.
- **Per-capture cost is ~8 ms and barely depends on area** — single-pixel `PixelGetColor`
  8.35 ms, `PixelGetColor "Alt"` 8.27 ms, a 780x42 worst-case `PixelSearch` 7.83 ms. So
  **one `PixelSearch` beats several `PixelGetColor` calls**, and the state machine should
  exit detection early on first match. Ceiling is ~120 captures/sec.
- **`PixelSearch` returns only the FIRST match** (top-to-bottom, left-to-right), so static
  bright scenery masks everything after it — a sweep for near-white kept returning a lamp at
  (1649,444) and never saw the cast meter. Bound every search tightly, or verify the hit with
  a second read. This is a silent false-negative generator.
- **Animation noise floor, measured:** ~8 of 72 sampled points shift by >24 on a channel
  with no input at all, because water and lighting move constantly. Every tolerance must
  clear this.
- **The hotbar strip is a strong, cheap state discriminator.** Bright-pixel count over
  client x 0.375..0.625, y 0.935..0.995 reads **9 with the hotbar present, 0 when absent**,
  noise ~1. It is large, high-contrast and screen-anchored — much more robust than the thin
  cast meter — and separates `casting`/`fish_on` from `idle`/`bait`/`success`.
- Python 3.14 with **Pillow 12.1.1** is available, so sampling exact colours out of the
  PNGs is an AFK-able job -- no need to ask the user to eyedrop.
- Repo has no `.scratch/` before this map, no code, and is **not a git repo**. So research
  findings go to files under this effort, not to a `research/<name>` branch.

**Observations already lifted off the screenshots.** Starting points for
[Pixel signature for each Status](issues/04-status-pixel-signatures.md) -- all approximate,
in 1920x1080 coordinates, and all still needing live confirmation:

- **Cast meter** (`casting.png`): vertical bar around x=1117, spanning y=455..690, with a
  green tick at the top edge (y=450..462). Sits to the right of the character -- suspicious,
  see fog below.
- **SHAKE circle** (`bait.png`): centred near (1302, 700) -- clearly *not* screen-centred,
  so it very likely roams. Mostly irrelevant now that shake is a keypress, but it is also
  the cheapest positive tell that `Status` is `bait`, so it may still need detecting.
- **Reel bar** (`fish_on.png`): dark track x=570..1350 at y=900..945, with small triangle
  end-caps just outside at x~557 and x~1363. Separate catch-progress bar below at y~980
  spanning x=748..1170, filling left to right. Caption "+20% Progress Speed" beneath.
- **The free on-target signal.** Comparing `fish_on.png` with `fish_on2.png`: the
  player-controlled zone is **white** when the fish line sits inside it, and **tan/brown**
  when the fish line sits outside it. If that holds, steering needs only a binary
  "am I on target?" colour read rather than tracking two moving x-positions. This is the
  single most promising simplification on the map --
  [How the reel minigame gets steered](issues/05-reel-steering-strategy.md) exists to
  confirm or kill it.
- **Hotbar as a discriminator**: the item hotbar (x=720..1200, y=1005..1080) is present in
  `idle`, `bait` and `success`, and absent in `casting` and `fish_on`.
- **Success text** (`sucess.png`): "You just caught a ... at ...!" centred at y~845 with
  "Bestiary:" on the line below. Fish name and weight vary, so match on layout and colour,
  never on text.

**Skills every session on this map should consult:** `/grilling` and `/domain-modeling` for
the decision tickets, `/prototype` for the prototype tickets, `/research` for
[Prior art](issues/03-prior-art.md).

**Speak plainly.** The user is steering by outcome, not by implementation. Anything put in
front of them -- questions, findings, the status line copy -- uses everyday words and comes
with a recommended answer. Ticket bodies can be as technical as needed.

## Decisions so far

<!-- the index -- one line per closed ticket. Gist only; the detail lives in the ticket. -->

- [Tune it against a live session](issues/12-tune-against-live-session.md)
  — **the destination, reached.** 49 of 49 hooked fish landed across three consecutive runs (95%
  lower bound 94.1%), from 0 of 3 at the start. Eleven bounded live runs. The change that did it
  was **~450 ms of actuation dead time**: the bar travels a median 144 px after being told to
  reverse, against a 116 px tolerance, so `reelDampMs` had to go from 40 to 450. Before that, the
  fish detector had to be fixed — it was returning warm brown scenery ~340 px off, and every other
  reel measurement was being taken through it.

- [The SHAKE ring detector false-positives on open sea](issues/19-ring-false-positive-open-sea.md)
  — **stop asking.** The ring is now read only while a line is in the water. It also turned out a
  false bite was discarding the bite-wait guard and making the bot re-cast over its own line;
  casts-to-catch went 66.7% → 94-100%.

- [Read on-target from the white around the fish, not the bar's position](issues/20-on-target-from-white-around-fish.md)
  — the user's call, and now **the authoritative signal**: the game paints the bar white exactly
  while the fish is inside it, so a small box around the fish reads the game's own scoring state
  instead of inferring it from geometry. **0 errors across 276 real frames and ~30k swept
  positions.** It is one bit, so the bar search survives only as a *direction hint*, believed
  when it agrees with the white test and abandoned after 1.2 s of steering with nothing to show.
  Actuation is back to holding the button.

- [A stale settings file silently overrides improved defaults](issues/15-settings-version-stamp.md)
  — **keep what the user tuned, move everything untouched to the new default.** Needs provenance,
  so the file now records the shipped default each value was saved against. Chosen over
  discarding the whole tuning section, which was implemented first and rejected. Plus a *Reset to
  defaults* button.

- [Visual overlay: show where we look and what we found](issues/18-detection-overlay.md)
  — **Red outlines for every search region, blue markers for every hit**, and the script
  cannot see its own overlay.

  The obstacle was that an overlay drawn over the game is, to `PixelSearch`, just more
  screen — red boxes would be detected as red. Solved with
  `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)`, **tested before being relied on**: with
  it set, a read under the overlay returns the game (`0x070A2A`) rather than the overlay
  (`0xFF00FF`), and a search for the overlay colour finds nothing. Confirmed no regression —
  10 casts / 6 hooks with it on, against 9 / 6 with it off.

  Two lessons. First, **`WS_EX_LAYERED` without an initialised transparency renders nothing
  at all** — the first version drew zero pixels; measured 0 vs 7200 for the same window
  without the style. Second, the overlay initially showed boxes but never a single marker,
  because the detectors only ran while the loop was running: **a debugging aid is most needed
  when the thing is stopped**, so the overlay now re-runs the detectors on its own timer.
- [Will this run on a different PC?](issues/17-portability-to-another-pc.md)
  — **At 1920x1080 borderless fullscreen, yes. At another resolution, no — and now it says
  so instead of failing silently.**

  One real bug found: `SX()`/`SY()` scaled *positions* but nothing scaled *lengths*, so
  twelve thresholds (zone widths, the steering dead zone, velocity clamps, search skips)
  were reference pixels compared against screen pixels. Invisible at 1920x1080 where the
  scale is exactly 1.0; at 2560x1440 every threshold would be 25% too tight. Fixed with
  `SW()`/`SH()` length converters.

  One limitation that **cannot** be engineered away, established by testing rather than
  assuming: **Roblox's interface does not scale purely proportionally.** Resized to a clean
  16:9 1280x720 client, the hotbar grows relatively taller and bleeds into the progress-bar
  box — the script then believed a fish was permanently hooked and **cast zero times in 150
  seconds**. Positions scale; the layout itself does not.

  The most valuable thing built was a **contradiction check**, and the reason it exists is
  worth remembering: *the first version of the doctor passed that broken 720p setup as "all
  clear"*. Every individual check succeeded while the loop was completely dead. The fix was
  to assert a relationship the game cannot violate — the hotbar is hidden while reeling, so
  "hotbar AND progress bar both visible" is impossible — and that catches it immediately.
  **Checking components individually is not the same as checking that the system is
  coherent.**

  Also shipped: `doctor [seconds]` (read-only, sends no input, actionable remedies, watches
  while you fish by hand so reel-only detectors get exercised) and INI-overridable detector
  boxes so another resolution can be recalibrated without editing code.
- [Answer SHAKE with a keypress](issues/02-shake-via-keypress.md)
  — **Reversed twice, and the user was right both times.** Enter answers a SHAKE prompt
  directly: no accessibility toggle, no chat box (verified by screenshot after a 150 s run
  of pure Enter presses), and slightly *better* than clicking — 2.42 hooks/min versus 2.15,
  39 shakes per hook versus 44. It is now the shipped method, with ring-clicking kept as a
  checkbox fallback. The ring detector survives, but only to decide whether a prompt is on
  screen; with a keypress its exact position stops mattering.

  **The lesson is about deference, not shake buttons.** Research found no Fisch shake
  setting and inferred Enter must therefore work through Roblox's shared-highlight UI
  Selection Toggle and be unreliable. That inference was reasonable and simply wrong. A
  user who actually plays the game outranks an inference built on an absence of
  documentation — and they had said "click it or press enter" in their very first message.
- [Rework the reel steering with measured dynamics](issues/16-reel-steering-rework.md)
  — **The fish now stays inside the zone 88% of the time** (previously unmeasurable), aim
  error down from 108 px to 34 px, and reels complete in 7–13 s instead of one 47.7 s
  losing struggle. Confirmed live: Level 4 → **Level 5**, cash 2,650 → 2,740 C$.

  Three faults fixed, each exposed by tracing the controller's own decisions rather than by
  reading the code: it aimed at the zone's **left edge** (PixelSearch returns the leftmost
  match); it could only find the zone **while already on target** (it hunted white, but the
  zone is warm brown when off-target); and it had **no velocity term** at all.

  Two `PixelSearch` traps were cleared on the way, both worth remembering: the zone search
  must **exclude the track's end-caps** (a light left cap gave a bogus 67 px zone pinned in
  place, while the mouse was held 97% of the time), and it must run along **a single scan
  line** — a multi-row rectangle makes left-to-right bracketing meaningless and gave 0%
  detection. Detection went 0% → **97%**, with a measured zone width of 232 px against an
  expected 231.

  The finesse itself was two things: **predict the fish** (lead it by 70 ms; it darts at up
  to 484 px/s) and **damp against the zone's own momentum** (the zone *accelerates*, spread
  ±400 px/s, so steer on `error − zoneVel × 150 ms` to reverse before overshooting). Plus a
  correction of principle that mattered as much as the control law: **the fish only has to
  be inside the zone, not centred in it** — the half-width is ~116 px, so the original 14 px
  dead zone demanded precision the game never asks for and guaranteed chatter.
- **THE SCRIPT IS BUILT AND IT CATCHES FISH** —
  [`fisch-autofisher.ahk`](../../fisch-autofisher.ahk), ~776 lines of AHK v2, resolving
  tickets [05](issues/05-reel-steering-strategy.md), [06](issues/06-plain-cast-hold-time.md),
  [08](issues/08-status-state-machine.md), [09](issues/09-control-window.md),
  [10](issues/10-settings-and-proportional-coords.md) and
  [11](issues/11-build-the-script.md) in one overnight session on explicit user
  authorisation. **Proof: the character went Level 3 -> Level 4 across a 240 s run**, and
  Fisch grants XP only for landed catches. Final run: 18 casts, 11 hooks, 350 shake clicks,
  1 failed cast, mouse verified released afterwards.

  Four bounded runs were needed, and each failure taught something the screenshots could not:

  1. **89 casts, 0 bites.** A stateless `idle` fall-through re-casts immediately and cancels
     its own line. Fixed with one piece of memory (`NextCastAt`) — `idle` now means "waiting
     for a bite" for up to 12 s.
  2. **13 casts, 0 bites.** The control window floats above fullscreen Roblox, so clicks made
     while the cursor sat over it went to the window. Fixed by aiming at an in-game point
     first, and hiding the window during headless runs.
  3. **0 casts registering at all.** The rod had become unequipped, and nothing noticed —
     the loop reported success regardless. Fixed by *verifying* each cast against the
     live-verified "hotbar hides while casting" signal, and self-healing via hotbar slot 1.
     Also learned: **Roblox hotbar number keys toggle**, so pressing `1` can unequip.
  4. **12 failed casts per run.** The first cast straight after a reel always fails (the game
     is still landing the fish), and toggling the rod in response *unequipped a working rod*.
     Fixed with a 2500 ms post-reel settle and a 3-failure threshold before touching the rod.
     **Failed casts fell from 12 to 1.**

  The reusable lesson: every one of these was invisible to static analysis and obvious within
  one bounded live run. The `runfor <seconds>` and `selftest` modes exist so future changes
  can be checked the same way.
- [Is the cast meter's position fixed across casts?](issues/13-cast-meter-fixed-position.md)
  — **Moot: the fixed cast-meter probe is unusable whatever the meter does**, because the
  character's own white glove occupies that box while idle (1/4 true positives, 18/93 false
  positives live). `casting` is detected by the verified fallback instead: **hotbar strip has
  no near-white AND progress bar has no near-white** (4/4, zero false positives).
- **⚠ [Pixel signature for each Status](issues/04-status-pixel-signatures.md) was CORRECTED
  the same night by live verification — see its "LIVE-VERIFIED SIGNATURE SET" section, not
  its original table.** The screenshot-derived signatures collapsed live: the cast-meter probe
  scored 1/4 with 18/93 false positives, the "dark pixel in the track band" test for `fish_on`
  fired 40/40 while idle, and the cyan `bait` ring matched the daytime sky ~60 times. Root
  cause, and the reusable lesson: **the reference screenshots are sound for GEOMETRY but not
  for COLOUR THRESHOLDS** — they are six frames from one time of day, one camera position,
  with no leaderboard panel and no `[AFK]` tag. What survived, measured across a live
  night-to-day swing: `fish_on` ⟺ near-white in the progress-bar band (10/10, 1/87), and
  `casting` ⟺ hotbar strip has no near-white (4/4, 0 false positives). Both are *bright UI
  inside a small fixed box*, tested for presence rather than matched to a colour. `0x434B5B`
  for the fish line was confirmed live. **`bait` has no working detector — the main gap.**
- [Pixel signature for each Status](issues/04-status-pixel-signatures.md)
  — **A cross-validated signature table now exists, and the colour-flip hypothesis is
  CONFIRMED.** Measured with numpy/Pillow from the screenshots and checked against all six
  frames. `casting`: one pixel at (1116, 650) reads `0xE9E9DF` versus `0x14..0x2F` in every
  other state — **margin 176**, the strongest signature on the map. `success`: near-white in
  x 700..1250, y **840..885** hits 1317 px and **exactly 0** in all five other states.
  `fish_on`: the track is a dark trough — non-fish states never leave luma 104..129, fish
  states read 22..30. `bait` stays weak (the ring roams). **The reel zone is `0xF1F1F1`
  white with the fish inside it and `0x53372F` warm with the fish outside** — so one colour
  read answers "am I on target?", which de-risks
  [How the reel minigame gets steered](issues/05-reel-steering-strategy.md). Zone width
  measured at 231 px = 29.7% of the track, independently confirming the wiki's "30% at 0
  Control". Fish line is `0x434B5B`, stable across both frames. Two corrections to earlier
  beliefs: the hotbar is **binary only** (its middle tier is a buff caption), and tolerances
  should come from the **live** noise floor (≥25 with world behind, ~15 on UI chrome), not
  the far cleaner PNGs.
- [Can AutoHotkey read pixels out of the Roblox window?](issues/01-can-ahk-see-roblox-pixels.md)
  — **Yes, and input lands too. The approach is viable.** All three capture paths returned
  real varied pixels with zero black readings; `PixelSearch` and `PixelGetColor` agreed.
  `SendInput` reaches the game for both mouse and keyboard — proven by the hotbar vanishing
  (9 bright px -> 0) during a held click and returning after release, i.e. a real cast. No
  elevation needed. **Reads do not need focus; input does**, so unattended means leave the
  PC alone. **Every capture costs ~8 ms regardless of area** (single pixel 8.35 ms, a
  780x42 `PixelSearch` 7.83 ms), which *inverts* the plan for
  [Pixel signature for each Status](issues/04-status-pixel-signatures.md): prefer one
  `PixelSearch` over several `PixelGetColor` calls. Confirmed the coordinate correction
  live — with the script's own GUI focused, `Client`/`Window` mode read the GUI's grey
  (`0x0F0F0F`) instead of Roblox. Two new traps found: `PixelSearch` returns only the first
  match so static bright scenery masks everything after it, and the hotbar strip turns out
  to be an excellent cheap state discriminator.
- [Prior art: Fisch macros, the old POE2 AHK notes, and Roblox pixel reading](issues/03-prior-art.md)
  — Corrected three things this map had wrong: the coordinate mode (window-relative anchors
  to the *foreground* window, so the control GUI would silently break every read), the SHAKE
  mechanism (Roblox's `\` UI Selection Toggle, not a Fisch setting), and the timing
  justification (no source supports macro-detection; Fisch's dev says use is allowed).
  Established that the black-screen risk is compositor bypass rather than DirectX, so
  PixelSearch is probably fine but still needs proving; that `"Alt"` is the only genuinely
  different capture path to probe; and that v1→v2 swaps colour literals red/blue, silently.
  Found perfect cast is worth **distance only**, and that the reel zone's width is a **rod
  stat** (30–70%) that must never be hard-coded. POE2 turned out to be Path of Exile 2 —
  no Roblox lessons, but strong AHK v2 GUI craft, including a bug that cost three sessions.

- [Pinion Aria rod: spelling, stats, obtain method, reel-UI mechanic, and macro
  precedent](issues/21-pinion-aria-rod.md) — **the vault todo's gloss is corrected, not
  confirmed.** The rod is really named **Pinion's Aria**, and nothing in five
  cross-checked sources says it recolours the fish marker or the bar; instead it overlays
  a falling-note rhythm minigame that resizes the bar live (±20 points of Control per
  note hit or missed) and, after 7 notes in a row, locks the fish's *position* to the bar
  during a "Resonance" state — a geometry/timing effect, not a colour one. Six inspected
  open-source Fisch macros never special-case this rod by name; the closest precedent is
  one macro trying a short fixed list of alternate bar colours as a fallback, and another
  explicitly disclaiming support for special/developer rods altogether. The official
  `fischipedia.org` wiki and its Fandom mirror were both completely unreadable by every
  method tried, so every claim rests on secondary guide sites instead.

- [Support Pinion's Aria: read its redrawn reel UI and catch every falling
  note](issues/22-pinion-aria-notes.md) — **built as `MarkerMode = 3`, unverified live.**
  Six reference frames showed the rod breaks every existing reading: pale track (blue
  186..217, so `darkMax` sees no track), a zone that is lit pale blue (≥ 251) inside and dim
  (≤ 162) or red outside, a cyan-topped marker neither old rule matches, and a red progress
  fill the bright test rejects. Each replacement rule was checked against all six frames
  before being written: identification by the pale track at one bar end, zone by blue
  distance from a per-tick track sample, fish by the marker's cyan top rows, on-target by a
  6 px lit run beside the marker, red fill accepted only inside an identified Aria fight.
  Notes are found on a 3×8 px grid over the lane above the bar (every glyph has a ≥ 13 px
  row; every false match is ≤ 9 px), the lowest is followed and its fall timed, and the bar
  commits to it only when ETA ≤ travel time + `ariaNoteLeadMs`, aiming for the point
  nearest the fish that keeps the note `ariaNoteMarginPx` inside the bar.
  **Tuned after the first live runs (same day):** the whole reel UI *fades in*, which let
  the old blue-grey rule latch the wrong rod on some fights (hence "the moving bar reads as
  the big bar") and hid single notes entering the screen. Identification is now a row-
  majority test re-run every tick, the track colour the row's median blue, and the note
  rule relative (blue leads, R≈G) with shape and position tests instead of absolute
  thresholds — see the ticket's Comments.

## Not yet specified

<!-- in-scope fog: real questions that cannot be phrased sharply until earlier tickets land -->

- ~~**Is the cast meter screen-fixed, or does it follow the camera?**~~ **GRADUATED
  2026-09-03** to [Is the cast meter's position fixed across casts?](issues/13-cast-meter-fixed-position.md).
  Now sharply phraseable: ticket 04 measured the meter at x 1112..1120, y 457..687 with a
  probe margin of 176, so the question is simply whether that position holds across casts
  and camera movement.
- **Does `bait` need positive detection at all,** or is it enough to tap Enter on a cadence
  until the reel bar appears? [Prior art](issues/03-prior-art.md) **nudged this toward
  "yes, it does"**: the Enter press works through Roblox's UI Selection Toggle, whose
  highlight is *shared stateful UI*, so Enter activates whatever happens to be selected --
  which is not necessarily the SHAKE button. Blind spamming is therefore riskier than
  assumed. Still fog because the real behaviour is unmeasured; graduates off
  [Answer SHAKE with a keypress](issues/02-shake-via-keypress.md).
- ~~**How much does Fisch's day/night lighting shift the colours?**~~ **GRADUATED 2026-09-03**
  to [Do the measured signatures hold in daylight and on the live screen?](issues/14-daylight-and-live-confirmation.md),
  which also absorbed PNG-vs-live drift and the SHAKE-ring roam mapping. Now sharply
  phraseable because ticket 04 produced concrete values to re-measure against.
- ~~**Does input need Roblox focused, and does it need elevation?**~~ **CLOSED 2026-09-03**
  by [Can AutoHotkey read pixels out of the Roblox window?](issues/01-can-ahk-see-roblox-pixels.md),
  measured live: **no elevation** (everything worked un-elevated), **reads are
  focus-independent**, **input needs focus**. Unattended means leave the PC alone.
- **What the loop does between catches** -- whether `success` needs an explicit dwell before
  re-casting, and whether the catch counter can double-count a single fish. Graduates off
  [The Status state machine](issues/08-status-state-machine.md).

## Out of scope

<!-- ruled beyond the destination. Never graduates. -->

- **Inventory, selling and walking** -- noticing a full bag, travelling to a seller, dumping
  the catch. Ruled out when scope was set to catch-loop-only: it means reading menus and
  moving the character, both far more fragile than reading a fixed bar.
- **Full unattended farming** -- rod durability, re-baiting, surviving the idle kick,
  restarting after a crash. Explicitly declined as a multi-session project of its own.
- ~~**Hunting the SHAKE circle visually**~~ — brought back into scope on 2026-09-03,
  then **demoted again to a fallback** once the user pointed out that Enter answers SHAKE
  directly (see [ticket 02](issues/02-shake-via-keypress.md)). The ring detector is still
  used to decide *whether* a prompt is on screen; only the clicking is retired. Original
  reasoning for bringing it back: This was ruled out on the condition that it "would return
  only if [ticket 02](issues/02-shake-via-keypress.md) finds the keyboard shake setting does
  not exist or does not work". That condition was met twice over: research established there
  is no Fisch shake setting (it is Roblox's `\` UI Selection Toggle, whose shared highlight
  makes Enter unreliable), and then a strict colour test for the ring turned out to work
  perfectly — `0x6CBEFF` ±40 fired on 54/54 frames with a visible ring and **zero** false
  positives across 90 frames spanning night and day. The shipped script clicks the ring and
  logged 350 successful shakes in one run. The original decision to prefer a keypress is
  therefore **reversed**, on evidence.
- **Per-resolution saved calibration profiles** -- superseded by proportional coordinates
  plus the manual picker.
- **Watchdog auto-stop on a no-catch streak** -- offered and declined; the user reports the
  cast -> shake -> `fish_on` chain is deterministic. Counters carry the signal instead.
- **Perfect-cast timing** --
  [Is the cast meter readable enough for a perfect cast?](issues/07-perfect-cast-readable.md)
  (closed 2026-09-03, not resolved). Ruled out because
  [Prior art](issues/03-prior-art.md) established a perfect cast increases the rod's maximum
  line length and **nothing else** — no catch-rate, rarity or progress-speed benefit. The
  destination is a stationary catch loop from one spot, so extra casting distance buys
  nothing, and this was simultaneously the hardest read on the screen. The user chose it as
  a droppable toggle before the payoff was known, and dropped it once told. Only returns if
  the destination is redrawn to need casting distance.

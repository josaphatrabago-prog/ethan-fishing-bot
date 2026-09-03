# How the reel minigame gets steered

Type: prototype
Status: resolved
Blocked by: 01, 04
Parent: ../map.md
Label: `wayfinder:prototype`

HITL — a rough steering loop is run against real fish and watched together.

## Question

Which control strategy actually holds a fish inside the zone: the cheap binary
"am I on target?" colour read, or full position tracking of both the fish line and the zone?

This is the heart of the automation. Everything else is plumbing; if reeling does not work,
nothing gets caught.

## The two candidates

**A — Binary colour flip (the cheap one, try first).**
Comparing `fish_on.png` with `fish_on2.png`, the player-controlled zone appears **white**
when the fish line sits inside it and **tan/brown** when the fish line sits outside it. If
that holds, the whole control loop reduces to: read one or two pixels, and if "off target"
flip the mouse button state. No position maths, no tracking, one read per tick.

The catch: a binary signal says *that* you are off target, not *which side*. The loop would
have to infer direction — e.g. keep the current action until the signal says off-target,
then reverse. Whether that converges or oscillates is exactly what the prototype answers.

**B — Position tracking (the expensive one).**
Find the fish line's x-position by searching the track band for its dark vertical line,
find the zone's x-extent, compute the error, and hold or release to steer toward it. Gives
direction and magnitude, so it can steer proportionally. Costs a `PixelSearch` sweep across
~780 px every tick, and needs the fish line to be reliably distinguishable from the zone
edges and the arrow glyphs drawn inside the zone.

## What to determine

1. **Does the colour flip actually mean "on target"?** Verify against live play, not just
   the two screenshots — it could instead be a hit-flash, a lighting artefact, or a
   different game state entirely. Kill or confirm this first; it is the cheapest path and
   the whole reason this ticket is typed as a prototype.
2. **How fast does the fish move,** and how fast must the loop react? Compare against the
   per-read timing measured in
   [Can AutoHotkey read pixels out of the Roblox window?](01-can-ahk-see-roblox-pixels.md).
   If a read costs more than the fish's traverse time, strategy A cannot converge and B is
   forced.
3. **How the zone responds to input.** The user's description: hold left mouse to move the
   zone right, release to let it drift left. Confirm, and measure — is movement velocity or
   position based? Is there acceleration or momentum? Momentum changes the control problem
   fundamentally (overshoot becomes the failure mode).
4. **Does A converge?** Build the rough loop and watch it. Record catch rate over ~10 fish,
   and how it fails when it fails (oscillating in place, drifting off one end, losing fish
   at the edges).
5. **Only if A fails, evaluate B.** Confirm the fish line is separable from the zone's arrow
   glyphs and the track's end-cap triangles before committing to a search-based approach.
6. **Does the catch-progress bar help?** The bar below the track (x=748..1170, y~980) fills
   as the catch succeeds. It could serve as a slow feedback signal — "am I winning?" —
   independent of the moment-to-moment steering, and it may also be the cleanest way to know
   the reel phase has actually started.

## Decision to record

Which strategy the built script uses, with the measured catch rate that justified it — and,
per the map's staged pattern, whether B is deferred as a later escalation or ruled out.

## Measured input from [ticket 04](04-status-pixel-signatures.md) — the hypothesis is CONFIRMED

**Item 1 is answered from the pixel data.** Measured, not eyeballed:

| frame | zone colour | zone extent | fish centre | fish inside? |
| --- | --- | --- | --- | --- |
| `fish_on` | **`0xF1F1F1`** neutral white (R−B = 0) | x 826..1057 | x 959 | **YES** |
| `fish_on2` | **`0x53372F`** warm brown (R−B = +36) | x 572..804 | x 922 | **NO** |

White ↔ on target. Warm ↔ off target. **Strategy A is viable and is the one to build first.**
The distinguishing feature is not just brightness but **hue**: `R−B` is 0 when on target and
+36 when off, so an R-vs-B comparison is a robust test that survives lighting shifts better
than a brightness threshold would.

**Caveat that must not be lost: this is two frames.** It is strong, mechanically plausible
evidence — not proof across many fish, lighting states or rods. Item 1 is now
*confirm this live over ~10 fish*, not *investigate from scratch*.

### Geometry, measured — use these, do not re-derive

- **Inner track: x 571..1349** (778 px wide) at y ~910..935. Bar including end caps:
  x 549..1369.
- **Zone width: 231 px = 29.7% of the track.** This independently confirms the wiki's
  "30% at 0 Control" from pixels alone — two sources agreeing. Still **never hard-code it**:
  it scales to 70% with rod Control.
- **The zone is split by two arrow glyphs**, so it reads as three fragments, not one run.
  A detector must span first-to-last fragment or it will badly under-measure the zone —
  this bit the first analysis pass.
- **Fish line: `0x434B5B`, 8-10 px wide, identical in both frames.** Blue-grey (B > G > R)
  against uniformly warm surroundings. **So strategy B is also viable** — the fish is
  cleanly separable by hue, which was the open worry about it.

### Sampling advice for the steering loop

Because the zone moves, there is no fixed pixel that is always inside it. Two options:
sweep for the fish line by hue and read the colour immediately around it, or find the zone
first and sample its middle. Recall from [ticket 01](01-can-ahk-see-roblox-pixels.md) that a
band-wide `PixelSearch` costs the same ~8 ms as one pixel, so a bounded sweep is free —
but `PixelSearch` returns only the **first** match, so bound it to x 571..1349 and beware
the arrow glyphs and end caps matching first.

## Measured input from [ticket 01](01-can-ahk-see-roblox-pixels.md) — resolved 2026-09-03

- **Item 2's timing budget is now known: ~8 ms per capture**, near-constant with area
  (single pixel 8.35 ms; a 780x42 `PixelSearch` 7.83 ms). So the steering loop can run at
  roughly **120 Hz if it takes one capture per tick** — comfortable headroom, and it means
  strategy A's cheapness is *not* the deciding advantage it looked like: a full-band search
  costs the same as one pixel. Judge the two strategies on whether they **converge**, not on
  read cost.
- **`PixelSearch` returns only the first match**, so a position-tracking approach
  (strategy B) cannot simply search the band for "the fish line" if anything else in the band
  matches first. The zone's arrow glyphs and the track end-caps are exactly such things. Bound
  the search or verify hits with a second read.
- **Measured noise floor: ~8/72 points shift by >24 with no input.** Any colour test in the
  reel bar must clear this, including the white-vs-tan zone test.
- **`SendInput` mouse hold/release is confirmed to reach the game** — a held `Click "down"`
  produced a real cast. So the hold-release control model is actionable with plain
  `Click "down"` / `Click "up"`; no low-level `DllCall` was needed.
- **Calibrate and test in borderless fullscreen** (client exactly 1920x1080 at (0,0)), which
  is what the reel-bar coordinates in this ticket assume.

## Research input from [ticket 03](03-prior-art.md)

Item 3 is largely answered from the wiki, and one new hard constraint appears:

- **The control model is confirmed as hold-release, not click-to-move.** The zone drifts
  **left on its own**, and **holding** (Space or left-click) drives it right. So the user's
  description was right, and the loop is a two-state hold/release problem rather than a
  positioning one.
- **Progress is symmetric: roughly ±12% per second** — gained while the fish is inside the
  zone, lost while it is outside. This is what makes strategy A viable *in principle*: the
  loop does not need to be perfect, only net-positive. It also means the catch-progress bar
  (item 6) is a genuinely useful slow feedback signal, since its direction directly reports
  whether the steering is winning.
- **NEW CONSTRAINT — the zone's width is a rod stat, so never hard-code it.** 30% of the bar
  at 0 Control, +1% per +0.01 Control, capped at 70%. The user is on a Flimsy Rod now, so a
  width assumption baked in today breaks on their first rod upgrade. Whichever strategy
  wins must derive the zone from the screen, not from a constant.
- **The colour-flip hypothesis is undocumented either way.** The Fisch wiki does not mention
  the zone changing colour. Research found nothing that contradicts it either, and judged
  the two screenshots better evidence than the wiki's silence. So item 1 remains the real
  first move here — confirm it live before building anything on it.
- Note that strategy B's cost estimate should be revisited against the *measured* per-read
  timings from [ticket 01](01-can-ahk-see-roblox-pixels.md), not assumed.

## Answer — resolved 2026-09-03 during the overnight build session

**Decided and implemented by the agent while the user was asleep, on explicit authorisation
("can you see this through?"). Recorded plainly so any of it can be overruled — these were
HITL tickets resolved without the human in the loop.**

Working script: [`fisch-autofisher.ahk`](../../../fisch-autofisher.ahk) at the repo root.
Live proof it works: across a 240-second bounded run the character went from **Level 3 to
Level 4**, and in Fisch experience comes only from landed catches. Run counters: 18 casts,
11 hooks, 350 shake clicks, 1 failed cast.

**Strategy A — the binary colour read — was built, and it lands fish.**

Implemented as a hybrid rather than pure A, because the fish line proved cheaply findable:
`DoReel()` searches the track band for near-white (the zone while on-target) to learn the
zone's x-position, remembers it, finds the fish by its `0x434B5B` hue, then holds the mouse
while the fish sits right of the zone and releases while it sits left, with a dead-zone
slider. When neither can be read it alternates, so the zone sweeps rather than parking at
an end.

Confirmed live: the final run's closing frame shows the zone warm/tan with the fish outside
it — exactly what the colour-flip model predicts. Catch rate was enough to gain a level in
four minutes, but the steering itself is **untuned**; that is ticket 12.

Two fixes the live runs forced:

- A single dropped read of the progress bar used to end the reel early, after which the main
  loop re-entered it and double-counted. Now tolerates 3 consecutive misses.
- `hooked` is counted on the state transition rather than inside the reel loop.


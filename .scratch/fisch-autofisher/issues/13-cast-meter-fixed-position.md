# Is the cast meter's position fixed across casts?

Type: task
Status: resolved
Blocked by: —
Parent: ../map.md
Label: `wayfinder:task`

HITL — needs live casting with deliberate camera movement.
**Graduated from the map's fog** by [Pixel signature for each Status](04-status-pixel-signatures.md)
on 2026-09-03, which produced a superb `casting` probe but could not test its stability from
a single frame.

## Question

Does the cast meter stay at the same screen position across casts and camera movement — so
that the fixed probe at **(1116, 650)** works — or does it follow the camera, in which case
`casting` needs a different signature entirely?

## Why it matters now

[Pixel signature for each Status](04-status-pixel-signatures.md) measured the meter as a
near-white vertical run at **x 1112..1120, y 457..687**, and the probe at (1116, 650) reads
`0xE9E9DF` against `0x140B12`..`0x2F181B` in every other state — **a margin of 176**. It is
the strongest signature on the whole map.

It is also entirely unverified for stability, because it came from **one screenshot**. And
there is a specific reason to doubt it: the meter sits *beside the character* rather than
centred, which is exactly what a world-anchored billboard attached to the rod tip looks like.
The camera keeps the character centred, so a single frame cannot distinguish the two cases.

This is no longer about perfect-cast timing — that went out of scope. It is about whether
`casting` can be **detected at all** by the cheap route.

## What to determine

1. **Cast repeatedly without touching the camera.** Does the bright run land at x 1112..1120
   every time? Record the x range across ~10 casts.
2. **Cast while panning the camera** left, right, up, down, and while zoomed in and out.
   Does the meter move with it? Record how far.
3. **Cast while facing different directions** on the dock, and from a different fishing spot
   if convenient.
4. **Does shift-lock or a locked camera pin it?** If the meter tracks the camera but a locked
   camera holds it still, that is a viable prerequisite to document — the same class of
   prerequisite as borderless fullscreen.
5. **If it does move: how wide a band would a search need?** Record the full extent the meter
   was ever seen in. Remember from
   [ticket 01](01-can-ahk-see-roblox-pixels.md) that a `PixelSearch` band costs the same
   ~8 ms as a single pixel, so a wide bounded search is cheap — provided nothing brighter
   sits inside the band and masks it (a static lamp at (1649,444) already did exactly that).

## The fallback if the answer is "it moves"

`casting` then needs a different tell. Candidates, in order of promise:

- **The hotbar's absence.** Measured: the hotbar strip reads ~2466 near-white pixels in
  `idle`/`bait`/`success` and **0** in `casting`. That is a clean binary. The catch is that
  `fish_on` also hides the hotbar — but `fish_on` has its own strong signature (the dark
  track), so "hotbar absent AND track absent" would isolate `casting` with no meter involved.
  **This may well be the better signature regardless of what this ticket finds.** Evaluate it
  properly rather than treating it as a consolation prize.
- The rod's own animation, which is scene-dependent and probably too fragile.

## Answer

**RESOLVED 2026-09-03 — and the answer makes the question moot.**

The fixed-probe approach is **unusable regardless of whether the meter moves**, so the
camera-panning test was never needed.

**Why:** live-measured over 97 samples, the probe at (1116, 650) / (1116, 572) scored
**1/4 true positives and 18/93 false positives**. Min-channel readings:

| state | meterA min-channel | meterB min-channel |
| --- | --- | --- |
| idle / bait | **65..255** | **50..208** |
| casting | 94..212 | 68..71 |

Complete overlap. The cause is visible in the live frames: **the character's white glove and
sleeve sit in that region while idle.** The reference screenshot happened to have the arm
elsewhere, which is where the phantom "margin 176" came from. The meter's positional
stability is irrelevant when the probe box is occupied by the player model.

**Decision: detect `casting` by the fallback, which is now live-verified.**

```text
casting <=> hotbar strip has NO near-white  AND  progress bar has NO near-white
```

The hotbar-absent signal scored **4/4 with zero false positives** across the same 97
samples, including a full night-to-day lighting swing. It is bright UI over dark chrome at a
fixed screen position — structurally the right kind of signal, unlike a probe that can be
walked over by the character.

The fallback this ticket listed as a "consolation prize" is in fact the better signature, as
the ticket itself suspected. Full data in
[Pixel signature for each Status](04-status-pixel-signatures.md) under
"LIVE-VERIFIED SIGNATURE SET".

**Not tested, and no longer worth testing:** whether the meter tracks the camera. If a future
need for the meter arises (it currently has none — perfect cast is out of scope), start by
finding a probe box the player model cannot enter.

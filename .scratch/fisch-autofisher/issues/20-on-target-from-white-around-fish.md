# Read on-target from the white around the fish, not the bar's position

Type: grilling
Status: resolved
Blocked by: —
Parent: ../map.md
Label: `wayfinder:grilling`

The user's call, made after watching the reel bar be mis-detected repeatedly. It replaces the
question [Rework the reel steering with measured dynamics](16-reel-steering-rework.md) was
answering, and supersedes the bar-localisation half of it.

## Question

The reel controller needs to know whether the fish is inside the bar. Every attempt so far has
answered that by **locating the bar** and comparing positions — and bar localisation is the
least reliable reading in the script: 96–98% at the dock, but ~50% on open sea.

The user proposed inverting it:

> Instead of detecting where the white is. We do this: When detecting the fish. Scan the
> surrounding pixel (box around where the fish is detected) and see if there is white. If white
> is there meaning the fish is in the box, if not then fish is not in the box.

Is that reliable, and is it enough to steer on?

## Why it is a better question than the one it replaces

The fish marker detects at **100%**. The bar does not. Anchoring the test to the fish means the
measurement is always taken somewhere real.

More importantly, the game **paints the bar white exactly while the fish is inside it** — the
user established this earlier, when they pointed out the bar "changes to color to grey from
white when it is off the fish". So looking for white next to the fish does not *infer* the
on-target state from geometry: it reads the game's own scoring state directly.

## Answer

**Adopted, and it is now the authoritative signal.** Implemented as `FishOnTarget(fishX)`.

### Measured, before writing any of it

Against 869 captured frames of a real reel fight, of which **277 are genuine reel frames**
(bar present at plausible width, fish found):

| Test | Result |
| --- | --- |
| White within R px of the fish, R = 8…30, threshold 150…215 | **0 false positives, 0 false negatives** |
| The exact 2D box the script uses (±14 x, ±6 y, `tolWhite` 40) | **276/276** |
| Same test swept across ~30k sampled positions per-frame, vs the widest-run ground truth | **0 errors at every radius and threshold** |

The sweep matters: the dataset has **no genuine off-target frames** — in all 277 real frames the
fish was inside the bar, and the 9 that first looked like counter-examples were junk (bright
purple `#AE8CFF` UI, not the fish marker). So "100% correct" on the frames alone would only
have proven the absence of false *negatives*. Sweeping every position across the real track
pixels supplies the missing half honestly, because the test asks about a position's
**surroundings** and does not care whether a fish is actually standing there.

It is also unbothered by the fish glyph covering the middle of the box: the bar's white still
shows at the edges, which is why even R = 8 works.

### What it cannot do, and what was done about it

It is **one bit**. It says *whether* the fish is inside the bar, never *which way to move* when
it is not. So the bar search is kept — but demoted from "the signal" to "a direction hint", and
believed only conditionally:

1. **On target** → the white test and the bar reading can only agree if the bar really is where
   the search said, so the fine error is trusted and used to centre the fish in the bar.
2. **Off target, bar reading agrees** → steer at it, no dead zone.
3. **Off target, readings disagree** → throw the bar reading away and probe: commit to one
   direction for `probeMs` (250 ms), then reverse. A wrong guess costs one window.
4. **Off target for longer than `distrustMs` (1200 ms) with nothing to show** → stop believing
   the bar even though it "agrees", and fall through to the probe.

Rule 4 exists because agreement is *strong* evidence when the fish is inside the bar and *weak*
evidence when it is outside: a bar found on scenery is usually far from the fish too, so it
agrees by coincidence. Without a deadline the loop would push at a phantom for the whole fight.

### Also changed alongside

Per the user, the actuation is back to **holding and releasing** the mouse button rather than
spamming clicks.

## Still to confirm

Offline validation only. **Not yet exercised live** — that belongs to
[Tune it against a live session](12-tune-against-live-session.md). The trace now records
`onTgt` and `trust` columns per tick, so the split between rules 1–4 above is measurable rather
than a matter of impression:

```
AutoHotkey64.exe fisch-autofisher.ahk reeltrace 180
```

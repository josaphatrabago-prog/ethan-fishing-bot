# Rework the reel steering with measured dynamics

Type: prototype
Status: resolved
Blocked by: 05
Parent: ../map.md
Label: `wayfinder:prototype`

Raised by the user after the first build: *"it needs to actively detect/search where
the fish is and then hold or release the left mouse button. So there is a bit of finesse
needed here."*

## Question

The shipped steering was crude. What does the reel minigame actually require, and what
control law meets it?

## What was wrong with the original

Three structural faults, all found by tracing the controller's own decisions:

1. **It aimed at the zone's left edge, not its centre.** `PixelSearch` returns the
   leftmost match, so "find the white zone" yielded the zone's left boundary. The fish was
   being steered at a point half a zone-width away from where it should have been.
2. **The zone was only findable when it was already on target.** The zone renders white
   with the fish inside and warm brown outside, and the detector only looked for white — so
   precisely when steering mattered most, it fell back on a stale position.
3. **No velocity at all.** Pure bang-bang chasing where the fish *was*.

## What was measured

From 314 live reeling frames plus a per-tick trace of the controller itself:

| Quantity | Measured |
| --- | --- |
| Fish indicator | a ~10 px **neutral blue-grey vertical bar**, mean `#484F60`, and it extends above and below the track |
| Fish speed | median **30 px/s**, p90 135, peak **484 px/s** |
| Track interior | median RGB **(34, 18, 29)** — near-black even in full daylight |
| Zone width | **232 px** median (29.7% of the 778 px track, matching the wiki's "30% at 0 Control") |
| Zone motion | **accelerates**; velocity spread ±400 px/s, not a fixed ±200 |
| Scan row | **y = 920**; y 908 and y 940 are the track's *border* rows |

## The three fixes, in the order the evidence forced them

**1. Bracket the zone instead of hunting one colour.** The zone is far brighter than the
near-black track in *both* its states, so: left edge = first non-track pixel, right edge =
first track pixel after it, centre = midpoint. Expressed in `PixelSearch` terms, "not the
track" is a search for white with variation 225, which matches any pixel whose every channel
exceeds 30.

Two traps had to be cleared first:

- The search must **exclude the end-cap triangles** (inner bounds x 578..1342). Starting at
  560 locked onto the light left cap and reported a bogus 67 px zone pinned to the left of
  the track — the trace showed the zone apparently never moving while the mouse was held 97%
  of the time.
- The search must run along **a single scan line**. `PixelSearch` sweeps a rectangle row by
  row, so over the 45 px band the "first dark pixel to the right" can come from any row,
  including inside the zone. With a band, detection was **0%**.

Result: zone detection went **0% -> 97%**, with a median measured width of **232 px**
against an expected 231.

**2. Predict the fish.** Estimate its velocity between ticks and aim at
`fishX + velocity * 70 ms`, so a dart is led rather than trailed. Readings that jump more
than 300 px between ticks are rejected as misdetections — one such glitch produced a
−5081 px/s spike in the trace.

**3. Damp against the zone's own momentum — this is the finesse.** The zone accelerates, so
bang-bang with a tight dead zone oscillated across the entire track. Steering instead on
`error − zoneVelocity * 150 ms` reverses *before* overshooting.

Alongside it, a correction of principle: **the fish only has to be INSIDE the zone, not
centred in it.** The zone's half-width is ~116 px, so a 14 px dead zone demanded precision
the game never asks for and guaranteed chatter. Widening it to 70 px was as important as the
damping. Within the dead zone the controller stops chasing and duty-cycles the button to
drift along with the fish, since the zone has only two speeds.

## Result

| Metric | Before | After |
| --- | --- | --- |
| Zone detected | 0–46% (and wrong when found) | **97%** |
| Zone width measured | 67 px (bogus) | **232 px** |
| **Fish inside the zone** | not measurable | **88% of ticks** |
| Aim error, median | 108 px | **34 px** |
| Control tick | 63 ms | 47 ms |
| Reel outcome | one 47.7 s struggle, lost | reels completing in **7–13 s** |

**Live confirmation: the character went Level 4 -> Level 5 and cash rose 2,650 -> 2,740 C$
during the test runs.** At 88% containment and ±12%/s progress the expected catch time is
~11 s, which matches the observed reel lengths — the reels are finishing because they are
being won.

## Left open

- The **success/caption detector is still off**, so `caught` reads 0 and the catch count
  comes from inference (level and cash rising) rather than measurement. Tracked in
  [ticket 14](14-daylight-and-live-confirmation.md).
- Button flips run at ~62% of ticks (~13/sec) during station-keeping. That is what
  duty-cycling costs, and it is within human range, but it is worth a look if input volume
  ever matters.
- `reelDeadPx`, `reelLeadMs` and `reelDampMs` are all sliders now and none has been swept
  for an optimum — [ticket 12](12-tune-against-live-session.md).

## Answer

Resolved 2026-09-03. See above.

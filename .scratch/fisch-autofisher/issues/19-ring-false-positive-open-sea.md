# The SHAKE ring detector false-positives on open sea

Type: task
Status: resolved
Blocked by: —
Parent: ../map.md
Label: `wayfinder:task`

Found on 2026-09-03 by the new detection overlay
([ticket 18](18-detection-overlay.md)) — which is a fair advertisement for the overlay.

## The problem

`doctor 12` at the character's current location (a boat on open sea, bright daylight)
reported the SHAKE ring detected in **41 of 53 samples while idle**. There was no shake
prompt on screen at any point.

| Detector | Seen in 53 samples | Correct? |
| --- | --- | --- |
| hotbar | 53 | yes |
| **SHAKE ring** | **41** | **no — false positive** |
| progress bar | 0 | yes |
| fish marker | 53 | harmless (only read during `fish_on`) |

## Why the earlier validation missed it

The ring test (`0x6CBEFF` +/- 40, effectively requiring blue >= 215) was validated at
**54/54 detections with zero false positives across 90 frames spanning night and day** — but
every one of those frames was **at the dock**, where the upper screen is sky seen past
buildings and pier structure.

On open sea a far larger share of the search box is bright sky and sun-lit water, and some
of it now clears the blue threshold. The test was fitted to one location, exactly as the
earlier colour thresholds were fitted to one time of day.

## Impact

Degraded rather than broken. A false `bait` makes the loop press Enter instead of casting
for that tick, which is harmless in itself — Enter with no prompt does nothing. The loop
still fishes: 10 casts and 6 hooks in a 150 s run at this location. But casting is being
delayed, and the shake counter is inflated.

## Options

1. **Add a second condition: the ring's dark interior.** The prompt is a bright ring around a
   dark disc, so requiring a dark pixel roughly one radius inward from the bright hit would
   reject sky, which has no such structure. This is the structural-signature approach that
   has worked everywhere else on this map, and is the recommended fix.
2. **Raise the blue threshold** further. Cheap, but it is the same fitting-to-a-scene mistake
   that caused this, one notch tighter.
3. **Bound the search region.** Hard: the ring roams widely by design.
4. **Drop positive `bait` detection** and press Enter on a cadence during the bite window.
   Enter is now known to be harmless when no prompt is showing, so this may be the simplest
   robust answer of all — worth weighing against option 1.

## Answer

**Resolved 2026-09-03 by option 4's cousin: stop asking.**

None of the pixel-level options were needed. The detector is now consulted **only while a line is
actually in the water** — inside the bite window a cast opens — and never while idle, because
while idle there is nothing to shake. That removes the entire false-positive class without
touching a single threshold.

The false readings were also doing more damage than this ticket recorded. Entering `bait` set
`NextCastAt := 0`, discarding the 12-second bite-wait guard, so a false bite made the loop
**re-cast over its own line** — and a second cast cancels the first. That is the hole whose cost
is recorded in the code as "89 casts and zero bites in 149 seconds". Entering `bait` no longer
touches the guard; a real bite ends the wait by itself when `fish_on` arrives.

Measured after: casts that convert to a landed fish went from 66.7% to **94-100%** of casts that
entered the water.

Same lesson as the catch caption, which had the same fix: **not looking is stronger than looking
harder.**

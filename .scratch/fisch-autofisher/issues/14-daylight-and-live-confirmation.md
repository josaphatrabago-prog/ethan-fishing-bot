# Do the measured signatures hold in daylight and on the live screen?

Type: task
Status: open
Blocked by: 04
Parent: ../map.md
Label: `wayfinder:task`

HITL — needs the game open across an in-game day/night cycle.
**Graduated from the map's fog** by [Pixel signature for each Status](04-status-pixel-signatures.md)
on 2026-09-03, which produced concrete numbers that are all measured at dusk.

## Question

Every colour in the signature table was sampled from **dusk/night screenshots**, and from
**PNG files rather than a live screen**. Do the values survive daylight, and do they survive
being read live?

## Two distinct sources of drift to separate

1. **Lighting.** Fisch has a day/night cycle. Probes with the game world behind them will
   shift; probes on solid UI chrome should not. The signature table was deliberately built
   from UI chrome for this reason, but that is a prediction, not a measurement.
2. **PNG vs live screen.** Screenshot encoding, any HDR or colour-management path, and
   driver-level processing can all shift values between a saved file and a live
   `PixelGetColor`. [Ticket 01](01-can-ahk-see-roblox-pixels.md) already showed live reads
   are noisier than the files (~8 of 72 points shifting >24 with no input, versus a max drift
   of **1** across a static-UI region in the PNGs).

Keep these apart in the report. They call for different fixes: lighting drift argues for a
second calibration set or better probe points, while live-vs-file drift argues only for a
wider tolerance.

## What to determine

For each row of the signature table in
[Pixel signature for each Status](04-status-pixel-signatures.md):

1. **Re-read every probe live, at night**, and record how far it sits from the PNG value.
   This isolates live-vs-file drift with lighting held constant.
2. **Re-read every probe live, in daylight**, and record the shift from the night reading.
3. **Report the worst-case per-channel drift per probe**, and set each tolerance from that
   plus headroom — rather than from the PNG figures, which are optimistically clean.
4. **Confirm the margins survive.** The margins measured were large (176 for `casting`, and
   non-fish states never leaving luma 104..129 in the track band). Verify they stay
   comfortable, and flag any that narrow to less than roughly double the drift.
5. **Check `success` specifically.** Its signature is "any near-white pixel in x 700..1250,
   y 840..885", which was **exactly zero** for all five other states. Confirm daylight does
   not put stray near-white pixels (bright sand, sun glare, a boat sail) into that band — it
   is the one probe whose region has open world behind it, so it is the most exposed.
6. **Map where the SHAKE ring roams.** Collect the ring's centre across ~15 baits and record
   the bounding box, so `bait` can use a bounded `PixelSearch` if it turns out to need
   positive detection at all. Folded in here from the ticket 04 leftovers; drop it if
   [Answer SHAKE with a keypress](02-shake-via-keypress.md) establishes that blind key
   presses make `bait` detection unnecessary.

## Decision to record

Which of the three remedies the design actually needs — a wider tolerance, a second
day/night calibration set, or different probe points — and the final tolerance per probe.
This resolves the map's lighting fog item.

Bear in mind the POE2 lesson from [ticket 03](03-prior-art.md): every tolerance shipped there
ended up a live slider because a hard-coded default was twice wrong. Whatever this ticket
concludes, the values belong on the calibration panel too.

## Progress — 2026-09-03 (substantial; ticket stays open)

**The lighting question is largely answered, by luck: the in-game time changed from night to
day during a live capture run**, so one dataset spans both. 97 clean samples.

**Scenery-backed probe points swing enormously** — any absolute threshold on them is unsound:

| point | max-channel range across the run |
| --- | --- |
| trackL (600, 922) | 17..135 |
| trackR (1300, 922) | 19..105 |
| progL (760, 982) | 19..255 |

**UI-region searches held perfectly** across the same swing: the progress-bar near-white test
scored 10/10 with 1 false positive in 87, and the hotbar-absent test 14/14 with none.

**So the answer to "which of the three remedies" is the third: choose probe points that are
lighting-stable** — meaning bright UI inside a small fixed box, tested for *presence* rather
than matched against an absolute colour. Neither a wider tolerance nor a second day/night
calibration set is needed for the two core signals. Recorded in
[Pixel signature for each Status](04-status-pixel-signatures.md).

Three items keep this ticket open:

1. **`success` is still untested live** (item 5). Its band x 700..1250, y 840..885 is the one
   with open world behind it, so daylight glare on water is a real false-positive risk. This
   is now the *most* exposed remaining signature.
2. **The SHAKE ring roam area is unmapped** (item 6), and the cyan detector proved unusable —
   it matched the daytime sky ~60 times. Needs either a much tighter blue-dominance test
   (the ring's `0x62B3FF` has B-R = 157; pastel sky is far below that) or abandoning positive
   `bait` detection.
3. **The progress-bar detector's 1 false positive in 87** wants hardening: require the
   near-white to be horizontally extended, or require two consecutive ticks to agree.

## Answer

Not yet resolved.

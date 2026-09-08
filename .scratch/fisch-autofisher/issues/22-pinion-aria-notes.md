# Support Pinion's Aria: read its redrawn reel UI and catch every falling note

Type: task
Status: resolved
Blocked by: 21
Parent: ../map.md
Label: `wayfinder:task`

The user's request, made after [ticket 21](21-pinion-aria-rod.md) found that the rod's real
mechanic is a falling-note overlay, not a colour change: "I want to be able to catch all the
notes while fishing when using this rod." Six reference frames were supplied
(`screenshots/aria1..6.png`, taken on the laptop — the user says the bar's *position* is the
same on the calibrated machine and only the *colours* differ).

## Question

Two things had to be true before any note could be caught:

1. **Can the existing detectors see this rod's bar at all?** They could not. Measured on the
   six frames at the scan row (y 920):
   - the **track** is pale lavender, blue 186..217 — not near-black, so `darkMax` (38) reads
     the whole track as "zone";
   - the **zone** is lit pale blue/pink (blue ≥ 251) with the fish inside and dim mauve
     (blue ≤ 162) or red (blue ~81) with it outside — so the white on-target test never fires;
   - the **fish marker** is an 8 px column fading cyan (top) to purple (bottom); neither the
     blue-grey rule nor the pale-achromatic rule matches it;
   - the **progress fill** turns red (#E06A6F) while losing, whose green (106) is under the
     120 the bright test needs — so the fight would be declared over 8 ticks into every bad
     patch.
2. **What does "catch a note" require?** Positional: the bar must be under the note when it
   reaches the bar (ticket 21's follow-up research, five secondary sources agreeing; the
   key-press rhythm game is the *Tranquility* rod, a different thing). Notes fall straight
   down within the track's width; `aria6.png` shows one about to land dead over the zone's
   centre.

## Answer

Built into `fisch-autofisher.ahk` as `MarkerMode = 3`, identified per fight before the older
marker rules are tried, and switchable with `ariaNotes` (default on). Every colour rule was
checked against all six frames before being written down:

| Reading | Rule | Checked on 6 frames |
| --- | --- | --- |
| Is it Aria? | one bar end has blue in 172..232 and R,G ≥ 120; the other end's darkest channel ≥ 100 | true on all 6; false on `fish_on.png`, `new_rod_reeling.png`, `grey bar outside fish.png` |
| Track vs zone | blue within [−14, +30] of this tick's track sample (both ends, zone-covered end dropped) | track 186..217, dim zone ≤ 162, lit zone ≥ 251 on every frame |
| Fish marker | rows 898..906: R ≤ 160, G ≥ 190, B ≥ 235, run ≥ 4 px | the marker and nothing else (one 1 px stray) |
| On target | 6 px run of blue ≥ 240 starting 14 px either side of the marker's centre | lit zone on the 3 inside frames; zone end-caps are 4 px so they cannot pass |
| Note glyph | B ≥ 245, G ≥ 190, R 165..215, some row ≥ 11 px wide | every glyph has a row ≥ 13 px; the feather over the fish and caught-note sparkles are ≤ 9 px |
| Red fill | `#E06A6F` ± 60 in the progress box, **only** while `MarkerMode = 3` | so red scenery can never start a phantom fight |

**Steering.** The lane above the bar (track width × y 0..888) is added to the per-tick grab
once the rod is identified and sampled on a 3 × 8 px grid, bottom row first, so the *lowest*
note is found; a hit row is re-read at full resolution to place the glyph's centre. Its fall
speed is timed live from the first note (default 400 px/s until then) and gives an ETA to the
bar. The bar commits to a note only when `ETA ≤ travel time + ariaNoteLeadMs`, and the target
is the point nearest the fish aim that still puts the note `ariaNoteMarginPx` inside the bar —
so the fish is kept whenever both fit, and the note wins when they do not. Each fight logs
"notes: N of M landed under the bar" and the measured fall speed.

**Not verified live.** Everything above is measured from stills; nothing has been run against
the game yet. Watch for, in order: (1) whether the track's blue on the desktop sits inside
172..232 — `doctor`/`selftest` print the zone and fish readings; (2) the fall speed the first
fight logs, and whether `ariaNoteLeadMs` 400 is early enough; (3) whether the zone ever goes
red *with the fish inside* (a missed-note flash?), which would read as off-target for that
moment; (4) the true catch criterion — centre-inside is assumed.

## Comments

- Falls under the existing rule "Per-rod geometry must be measured, never tabulated": the bar
  width on this rod changes mid-fight (205..302 px measured), which the per-tick
  `MeasureZoneRight` already handles.

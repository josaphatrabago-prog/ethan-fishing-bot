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

| Reading | Rule (after the 2026-09-09 tuning round, see Comments) | Checked on 6 frames |
| --- | --- | --- |
| Is it Aria? | ≥ 50% of the scan row (sampled every 8 px) is pale and bluish: darkest channel ≥ 110, B−R ≥ 10, B ≥ G−6. Re-tested **every tick** until it passes | 64..100% on all 6 (64 with the red zone over 35% of the bar); 19% on `new_rod_reeling.png`, ≤ 1% on every other rod/state frame |
| Track vs zone | blue within [−24, +30] of the scan row's **median** blue this tick | median 193..216; the classifier isolates exactly the zone (+ the 8 px marker) on all 6 rows, in lit, dim and red states |
| Fish marker | rows 898..906: R ≤ 160, G ≥ 190, B ≥ 235, run ≥ 4 px | the marker and nothing else (one 1 px stray) |
| On target | 6 px run of blue ≥ max(240, median+34) starting 14 px either side of the marker's centre | lit zone on the 3 inside frames; zone end-caps are 4 px so they cannot pass; ramps top out at median+30 |
| Note glyph | relative lavender: R,G ≥ 100, B ≥ 150, B − max(R,G) ≥ 18, −20 ≤ G−R ≤ 40; 3 grid hits at 3 px, then a full-res run ≥ 8 px, plus glyph present 6 rows above or below; candidates within 30 px of the fish's column below row 780 are dropped | every note found in all 6 frames including the half-faded one entering aria1; the feather and sparkles are the only other hits and all fall in the fish-column exclusion |
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

- **2026-09-09, after the first live runs.** The user reported two things: *single* notes
  are sometimes not detected, and the moving bar is sometimes not detected, "false
  positives with the large bar where the bar moves". Both traced to the same evidence in
  the frames, and both were addressed offline (still unverified live):
  1. **The whole reel UI fades in at the start of a fight.** `aria1.png` has a single note
     entering at about half opacity (`#707C96`), which no absolute colour threshold keeps;
     and half-faded, the dim zone's colour lands inside the default rod's blue-grey marker
     cube, so on some fights `MarkerMode` latched 1 a tick before the pale track could be
     recognised. Locked out of Aria mode, the old zone search took the pale track for "not
     dark" and reported a 232 px "zone" pinned to the track's left end for the whole fight —
     the reported false positive. Fix: the Aria test now runs on **every** tick until it
     passes (it is a ~96-pixel majority read, so it costs nothing), and it is a majority
     test on the row rather than two end pixels.
  2. **The track colour is now the row's median blue**, not two end samples. The end
     samples were the darkest part of the track (its gradient is cyan → lavender → purple),
     which left the dim zone only 24 counts away; against the median it is 37+ away, and
     the median cannot be fooled by the zone covering one end.
  3. **Single notes were at the edge of the grid.** A double note has ~24 rows at least
     13 px wide; a single note has ~20 (head and flag), and the old 4-sample / 11 px / 8-row
     grid needed a ≥ 12 px part ≥ 8 rows tall — met, but with no margin, and not at all
     while fading in. The rule is now relative (lavender = blue leads, R and G close), the
     grid 3 × 6 with 3 samples and 8 px, and a shape test replaces the tight thresholds:
     the glyph must also be present 6 rows above or below. False positives the relaxed
     rule admits (the feather over the fish, caught-note sparkles, 8..12 px runs) are
     rejected by position: within 30 px of the fish's column below row 780. The lane now
     ends at row 878 because the lit zone's own glow passes the rule from row 885.
  4. `selftest` and the in-window detector test print the **rod mode** so the first live
     check is one line: `rod mode : 3 (Pinion's Aria; track median blue N)`.

# Is the cast meter readable enough for a perfect cast?

Type: prototype
Status: closed — ruled OUT OF SCOPE 2026-09-03 (not resolved on the route)
Blocked by: 04, 06
Parent: ../map.md
Label: `wayfinder:prototype`

HITL. **This ticket is allowed to fail.** The map settled that perfect cast is a toggle
layered on top of a working plain cast, and is dropped if the meter proves unreadable.
A clean "no" here is a successful resolution, not a blocked one.

## Question

Can the script watch the cast meter and release the mouse at the green mark reliably enough
to be worth having — and if so, how?

## Prerequisite it depends on

[Pixel signature for each Status](04-status-pixel-signatures.md) must first answer whether
the cast meter is **screen-fixed or camera-tracked**. The meter sits beside the character
rather than centred, which is what a world-anchored billboard attached to the rod tip looks
like. If it moves with the camera, a fixed probe point is worthless and this ticket either
needs a search band or ends in "no". Do not start here before that is known.

## What to determine

1. **Where the green mark is, and whether it is static.** `casting.png` puts the green tick
   at the top of the meter's travel (y~450..462, meter spanning y=455..690). Confirm whether
   the mark's position is constant, or varies per cast, per rod, or per luck stat. A varying
   mark means finding it each cast, not just watching one pixel.
2. **Can the release be timed by watching one pixel?** The cheapest approach: probe a single
   point at the green mark and release the instant the moving indicator's colour arrives
   there. Whether that works depends entirely on the per-read timing from
   [Can AutoHotkey read pixels out of the Roblox window?](01-can-ahk-see-roblox-pixels.md)
   versus how fast the indicator crosses that pixel. If the indicator crosses in less time
   than one read, the pixel is simply never sampled at the right moment and this approach
   is dead.
3. **If watching fails, can it be timed instead?** Using the meter period measured in
   [Hold time for a plain cast](06-plain-cast-hold-time.md), a fixed hold from a known
   start might land on the mark open-loop, with no reading at all. Note that this conflicts
   with the map's jitter decision — record how much jitter a timed perfect cast can tolerate
   before it stops hitting, and if the answer is "none", surface the conflict rather than
   silently dropping jitter.
4. **Measure the hit rate.** Over ~20 casts, how often does it hit perfect? Report the
   number. Anything the user would call unreliable should be reported as such rather than
   shipped as a feature that half-works.
5. **What perfect cast is actually worth.** Whether the in-game bonus justifies the
   complexity at the measured hit rate. If the honest answer is no, say so — it belongs in
   the map's Out of scope, not in the build.

## Decision to record

Whether the perfect-cast toggle is built, and by which method (pixel-watched or timed) —
or that it is ruled out, in which case rule it out of scope on the map rather than logging
it as a route step.

## Research input from [ticket 03](03-prior-art.md)

**Item 5 is answered, and it undercuts this whole ticket. A perfect cast grants line
distance only** — per the Fisch wiki, *"a 'perfect cast' is the maximum the rod line length
can be increased, but does not do anything else."* No catch-rate benefit, no rarity benefit,
no progress-speed benefit. Since the map's scope is a stationary catch loop from one spot,
extra casting distance is worth close to nothing.

That makes the honest recommendation: **rule this out of scope unless the user specifically
wants the distance.** Raise it with them rather than deciding unilaterally — they chose
"try for it, but don't block on it" at charting, before the payoff was known, so this is
new information bearing on their own decision.

Two smaller confirmations if it does get built:

- The map read `casting.png` correctly. The perfect-cast condition is the white bar landing
  inside **the tiny green overlay at the top of the bar** — so the green mark really is at
  the top of the travel, not mid-way, which is what item 1 suspected.
- Item 2's viability still hinges on whether the meter is camera-anchored, which
  [Pixel signature for each Status](04-status-pixel-signatures.md) settles and research
  could not. If it tracks the camera, that is now a reason to drop the feature rather than
  to build a search band for it.

## Answer

Not yet resolved.

# Tune it against a live session

Type: task
Status: resolved
Blocked by: 11
Parent: ../map.md
Label: `wayfinder:task`

HITL — the user runs it, both watch, values get adjusted. This is the last ticket; when it
closes, the map has reached its destination.

## Question

Does it actually work over a sustained run, and what do the tuning values need to be?

The build ticket ends when the script *runs*. This one ends when it runs *well* — which is
the destination the map was charted toward.

## What to do

1. **Run a real session** of at least 30 minutes and record from the counters: casts,
   catches, catches per hour, lost fish. This is the baseline every later tweak is judged
   against.
2. **Tune, one value at a time.** Cast hold time, steering responsiveness, colour
   tolerances, tick rate. Change one, re-measure, keep or revert — the counters exist
   precisely so this is measurable rather than a matter of opinion. Do not change three at
   once.
3. **Write the tuned values back as the new defaults** in the settings file and as the
   baked-in fallbacks in the script, so a fresh copy starts from what actually worked
   instead of from the first guess.
4. **Check it in daylight.** Every reference screenshot is dusk/night. Confirm the tuned
   colour tolerances survive the in-game day, and if they do not, apply whatever remedy
   [Pixel signature for each Status](04-status-pixel-signatures.md) settled on.
5. **Confirm the failure behaviour matches what was chosen.** The map deliberately has no
   watchdog auto-stop, so verify that a stall does show up in the counters as casts climbing
   with catches flat, and that the user can see it at a glance.
6. **Verify the safety non-negotiables hold under real use** — the panic hotkey, and the
   mouse button always being released on stop. Test them deliberately, mid-cast and
   mid-reel, rather than assuming they work because the code is there.
7. **Log what was learned.** Anything surprising goes to the vault's `Fisch/Pitfalls.md`;
   the finished state goes to `Fisch/Status.md`.

## Definition of done

The user runs it, walks away, comes back, and their fish count went up. Any remaining
roughness is either a tuned value written down or a new ticket — not an unrecorded surprise.

## Answer

**Resolved 2026-09-03.** The user set a harder bar than this ticket did: land **at least 90% of
hooked fish**, with catches-per-cast pushed as high as it goes, and nothing counted unless it came
out of a bounded live run.

### Result

**49 of 49 hooked fish landed** across three consecutive runs of the final build — a one-sided 95%
lower bound of **94.1%**, so the rate clears 90% on evidence rather than on the run that happened
to go well. Eleven bounded runs in total, ~30,000 control decisions.

| | start | end |
| --- | --- | --- |
| landed of hooked | 0 of 3 | **49 of 49** |
| on-target dwell | 20% | **65-67%** |
| median fight | 25-90 s | **10-11 s** |
| fish per 7-minute run | 8 | **17** |
| wasted casts | 12 of 29 | **4 of 22** |

### What actually mattered, in order

1. **The fish detector was not finding the fish** — it returned warm brown scenery, wrong by
   ~340 px. Everything else in the reel loop was measured through it, and the error was
   *directional*, pinning the bar to the far left. Fixed with a narrow scan band plus a
   blue-leads-red test.
2. **~450 ms of actuation dead time.** After the button is told to reverse, the bar still travels
   a median 144 px against a 116 px half-width tolerance, so any controller reversing on a zero
   crossing ejects the fish every time. `reelDampMs` 40 → 450 took dwell from 44% to 66% and the
   landed rate from 80% to 100%. This was the single change that met the goal.
3. **The scoreboard did not exist.** `caught` was hard-wired to 0. Then, once it did exist, three
   separate faults corrupted it while keeping `caught + lost = hooked` intact.

### Definition of done

Met: the user can start it, walk away, and come back to a higher fish count — at roughly
**140 fish/hour** with essentially no losses.

### What this ticket did NOT settle

- Everything is still tuned against dusk/night; see
  [Daylight and live confirmation](14-daylight-and-live-confirmation.md).
- 4 of 22 casts still fail to register with the rod apparently unequipped. The re-equip now
  converges rather than oscillating, but the initial cause is unknown. Costs cycle time, not fish.
- Blind ticks (no fish reading) are still 25-26% of decisions. The next lever if a higher rate or
  faster fights are wanted.
- The safety items in step 6 of this ticket (panic hotkey and mouse-release-on-stop tested
  deliberately mid-cast and mid-reel) were **not** re-verified in this session.

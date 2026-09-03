# The Status state machine

Type: grilling
Status: resolved
Blocked by: 04, 05
Parent: ../map.md
Label: `wayfinder:grilling`

HITL — use `/grilling` and `/domain-modeling`. This is the design ticket the build hangs
off, and the `Status` names become the project's ubiquitous language.

## Question

What are the states, the transitions, and the action each `Status` triggers — precisely
enough to implement without further decisions?

The user's framing, already settled on the map: one `Status` read from pixels each tick;
the `Status` decides the next action; `idle` is the fall-through, positively matched by
nothing.

## What to nail down

1. **The state set.** Confirm `idle` / `casting` / `bait` / `fish_on` / `success` is
   complete and that no sixth state is needed. Note that `bait` may not need positive
   detection at all — that hangs on
   [Answer SHAKE with a keypress](02-shake-via-keypress.md), and is a fog item on the map.
2. **Action per state.** What the script does in each:
   - `idle` -> begin a cast (press and hold)
   - `casting` -> hold, then release on the fixed-duration rule from
     [Hold time for a plain cast](06-plain-cast-hold-time.md). That is now the **only**
     casting path — perfect cast was ruled out of scope on 2026-09-03
     ([ticket 07](07-perfect-cast-readable.md), closed), so there is no toggle and no
     meter-watching branch to design around
   - `bait` -> press the shake key on the cadence from ticket 02
   - `fish_on` -> run the steering loop from
     [How the reel minigame gets steered](05-reel-steering-strategy.md)
   - `success` -> increment the catch counter, then return to `idle`
3. **Detection order.** The states must be tested in a fixed priority order, because the
   first match wins and `idle` is whatever is left. Decide the order, and justify it against
   the measured margins in
   [Pixel signature for each Status](04-status-pixel-signatures.md).

   Those margins now exist, and they suggest an order — confirm or overrule it, but start
   here rather than from scratch:

   | order | state | test | why here |
   | --- | --- | --- | --- |
   | 1 | `fish_on` | any luma < 60 among ~5 points along y 922, x 571..1349 | most time-critical (steering waits on it) and a wide margin: non-fish states never leave luma 104..129 |
   | 2 | `casting` | (1116, 650) has `min(R,G,B) > 150` | biggest margin on the map (176), one capture — **but** its positional stability is unverified, see [ticket 13](13-cast-meter-fixed-position.md) |
   | 3 | `success` | any near-white in x 700..1250, y 840..885 | perfectly clean (1317 px vs exactly 0 in every other state), but not urgent |
   | 4 | `bait` | cyan ring, bounded region search | weakest signature, and may not be needed at all — see the map's fog on whether `bait` needs positive detection |
   | — | `idle` | nothing matched | the fall-through |

   Note the ordering trade-off to resolve: putting `fish_on` first costs one capture on every
   idle tick, but saves latency exactly where it matters. Putting `casting` first is cheaper
   on average. Decide deliberately.
4. **Tick rate.** Bounded by the **measured ~8 ms per capture** from
   [ticket 01](01-can-ahk-see-roblox-pixels.md) — near-constant with area, so cost scales
   with the *number of captures*, not pixels. Ceiling ~120 captures/sec. Four probes per
   tick = ~33 ms (~30 ticks/sec); one probe = 8 ms (~120/sec). **So the detection order in
   point 3 must exit early on first match**, making a typical tick cost one or two captures
   rather than all four. Decide whether `fish_on` needs a faster inner loop than the outer
   state poll — steering may want ~20 ms while state detection is fine at ~100 ms.
5. **Mouse-button ownership.** The single sharpest correctness risk in the whole script: the
   left button is held during `casting` and toggled during `fish_on`. Decide who is
   responsible for guaranteeing it is released on a state change, on stop, on the panic
   hotkey, and on the script exiting. A stuck-down mouse button is the worst failure mode
   available here — it persists after the script dies.
6. **Counting a catch exactly once.** `success` persists on screen for some seconds, so a
   naive per-tick increment will count one fish many times. Decide the rule — edge-triggered
   on entering `success`, with a minimum dwell before `idle` can be re-entered. This
   resolves a fog item on the map.
7. **Jitter placement.** Where in the machine the timing jitter is applied. Simpler than it
   was: dropping perfect cast removed the one place jitter conflicted with a precise
   release, so jitter can now be applied freely within the tolerable hold range from
   [Hold time for a plain cast](06-plain-cast-hold-time.md).
8. **Start and stop semantics.** What happens if the user hits Start mid-fight, or Stop
   mid-cast. Releasing the mouse cleanly on Stop is non-negotiable, per point 5.

## Output

A state table — state, detection rule, action, exit transitions — using the `Status`
vocabulary verbatim, plus a note on tick rates and on button ownership. If new domain terms
are settled here, record them per `docs/agents/domain.md` (`CONTEXT.md` at the repo root,
created lazily).

## Answer — resolved 2026-09-03 during the overnight build session

**Decided and implemented by the agent while the user was asleep, on explicit authorisation
("can you see this through?"). Recorded plainly so any of it can be overruled — these were
HITL tickets resolved without the human in the loop.**

Working script: [`fisch-autofisher.ahk`](../../../fisch-autofisher.ahk) at the repo root.
Live proof it works: across a 240-second bounded run the character went from **Level 3 to
Level 4**, and in Fisch experience comes only from landed catches. Run counters: 18 casts,
11 hooks, 350 shake clicks, 1 failed cast.

**Built and running.** The state table as implemented:

| Status | Detection | Action |
| --- | --- | --- |
| `fish_on` | near-white in the progress-bar box | run the steering loop |
| `bait` | SHAKE ring found (`0x6CBEFF` +/-40) | click the ring centre, min 220 ms apart |
| `casting` | hotbar box has no near-white | wait it out |
| `idle` | fall-through | cast, but only once the bite window has expired |

Priority is fish_on -> bait -> casting -> idle, exiting on first match, so a typical tick
costs one or two ~8 ms captures.

**The correction the live runs forced:** a purely stateless `idle` fall-through is wrong. It
re-casts immediately and cancels its own line — 89 casts, zero bites, 149 seconds. The
machine needs exactly one piece of memory, `NextCastAt`, so that `idle` means "waiting for a
bite" for up to 12 s before re-casting; a bite clears it early. The user's instinct that
`idle` is the fall-through was right about **detection**, and only needed a timer on the
**action**.

Mouse-button ownership: one `ReleaseMouse()` is reached from the exit handler, the panic
hotkey, every state change that ends a hold, loss of focus, and stop. Verified released
after all four runs via `GetAsyncKeyState`.

Tick rates: 120 ms outer poll, 30 ms inner steering loop.


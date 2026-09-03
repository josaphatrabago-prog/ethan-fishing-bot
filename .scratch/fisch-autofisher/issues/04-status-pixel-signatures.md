# Pixel signature for each Status

Type: task
Status: resolved
Blocked by: 01
Parent: ../map.md
Label: `wayfinder:task`

Was part AFK, part HITL. The AFK half answered the question; the HITL leftovers graduated
into tickets 13 and 14 rather than holding this one open.

## Question

For each `Status` the script must positively detect — `casting`, `bait`, `fish_on`,
`success` — what is the smallest, most reliable set of probe points and colours that
identifies it, and what tolerance does each need?

`idle` is deliberately excluded: the map settled that `idle` is the fall-through, matched by
nothing. If none of the four signatures hit, the `Status` is `idle`.

## Starting data

`screenshots/` holds one 1920x1080 frame per state. Python 3.14 with Pillow 12.1.1 is
available, so exact RGB values can be sampled straight out of the PNGs before touching the
live game. Approximate regions already lifted off them (see the map's Notes for the full
list):

| Status | Candidate tell | Rough region (1920x1080) |
| --- | --- | --- |
| `casting` | vertical white meter, green tick at top | x~1117, y=455..690; tick y=450..462 |
| `bait` | cyan/blue SHAKE ring | centred ~(1302, 700) — **roams** |
| `fish_on` | dark reel track + end-cap triangles | x=570..1350, y=900..945 |
| `fish_on` | catch-progress bar below the track | x=748..1170, y~980 |
| `success` | "You just caught a ..." caption | centred, y~845 |

Also available as a coarse discriminator: the item hotbar (x=720..1200, y=1005..1080) is
present in `idle`, `bait` and `success`, and absent in `casting` and `fish_on`.

## What to determine

1. **Exact colours.** Sample the real RGB at each candidate probe point from the PNGs.
   Record them, then confirm the same points live — screenshot compression and any HDR or
   colour-management path can shift values.
2. **Minimum probe set. — GUIDANCE INVERTED by ticket 01, read this before starting.**
   The original instruction here was to prefer one or two `PixelGetColor` reads over a
   `PixelSearch` sweep. **That was wrong.** Measured live: a single-pixel `PixelGetColor`
   costs **8.35 ms** and a worst-case `PixelSearch` over a 780x42 band costs **7.83 ms** —
   the cost is a fixed ~8 ms *per capture*, essentially independent of area. So **prefer one
   `PixelSearch` over several `PixelGetColor` calls**: four separate probes cost ~33 ms, one
   search ~8 ms. Design signatures around as few captures as possible, not as few pixels.

   A state is only usable if its probe cannot be confused with any *other* state's frame —
   verify each signature against all six screenshots, not just its own.
3. **Tolerance per probe.** How much variation each point tolerates before it false-matches
   another state. Report as a concrete tolerance number the script can use.
4. **Lighting stability.** Every screenshot is dusk/night. Capture the same states in
   daylight and report how far each colour moves. Then decide, and record, which of these
   the design needs: a wider tolerance, a second calibration set, or probe points chosen
   specifically for being lighting-stable (UI chrome tends to beat anything with the world
   showing through it). This resolves a fog item on the map.
5. **Is the cast meter screen-fixed?** The map's biggest open fog question. The meter sits
   beside the character, not centred, which is what a world-anchored billboard on the rod
   tip looks like. Determine by casting while panning and moving the camera:
   - if it holds one screen position, a fixed probe works
   - if it tracks the camera, record how far it moves, and whether a search band or a
     locked/shift-lock camera makes it tractable

   **This is now a detection question, not a timing one** — perfect cast went out of scope
   on 2026-09-03, so nothing needs the green mark read. But `casting` is still one of the
   four states that must be positively detected, and the meter is its only obvious tell. If
   the meter tracks the camera, find `casting` a different signature: the hotbar's absence
   and the rod animation are the candidates worth testing.
6. **Anything that covers a probe point.** Note whether the Roblox "Screenshot Taken" toast,
   the chat box, or player nametags can sit over any chosen probe point — two of the
   supplied screenshots have that toast visible in the bottom-right, which is a live warning.

## Output

A table of `Status` -> probe points (as **proportions of the window**, per the map's
coordinate decision, alongside the 1920x1080 pixel values) -> expected colour -> tolerance,
plus a note on lighting and on the cast-meter anchoring question.

## Measured input from [ticket 01](01-can-ahk-see-roblox-pixels.md) — resolved 2026-09-03

Hard numbers now exist; do not re-derive them.

- **Start from the hotbar, not the cast meter.** A bright-pixel count over client
  x 0.375..0.625, y 0.935..0.995 reads **9 with the hotbar present** and **0 when absent**,
  against a noise floor of ~1 — measured across many samples, and it flipped cleanly during
  a real cast. It is large, high-contrast, screen-anchored and cheap. Use it as the backbone
  that splits `casting`/`fish_on` from `idle`/`bait`/`success`, then disambiguate within each
  group. This is far more robust than the thin, possibly camera-anchored meter.

  > **PARTLY SUPERSEDED by this ticket's Answer.** The hotbar is only safe as a **binary**
  > (present / absent) — `fish_on`'s middle tier is the buff-dependent "+20% Progress Speed"
  > caption. And the cast meter turned out to be the *strongest* signature measured
  > (margin 176), not the weakest — though its positional stability is still unverified, now
  > tracked as [ticket 13](13-cast-meter-fixed-position.md).
- **`PixelSearch` returns only the FIRST match**, so static bright scenery masks everything
  after it. A near-white sweep across the mid-screen kept returning a **lamp at (1649,444)**
  and therefore never saw the cast meter at all. Bound every search tightly, or verify the
  returned coordinate with a second read. Expect this to be why a naive meter search fails.
- **Measured animation noise floor: ~8 of 72 sample points shift by >24 on a channel with
  no input.** Water and lighting move constantly, and consecutive reads of the same pixel
  differ (e.g. `0x282B5A` then `0x2A2E5B`). Every tolerance must clear this — item 3 now has
  a concrete lower bound.
- **Calibrate in borderless fullscreen only.** Client is exactly 1920x1080 at (0,0) with
  zero chrome, matching `screenshots/` pixel for pixel. (Maximized-windowed gives 1920x1017
  at a non-16:9 aspect and makes the screenshots useless.)
- **Reads do not need focus**, so this ticket's sampling can run while the user does
  something else — but the *game* must be foreground for any input.
- Sample values already captured at night, for orientation: the dark water sits around
  `0x000002`–`0x2A2E5B`, the sand around `0x9C6859`–`0xB07765`.

## Research input from [ticket 03](03-prior-art.md)

- **Colour literals are red/blue swapped between AHK v1 and v2.** v1 pixel colours were
  BGR; v2 is RGB. Every colour constant in this ticket's output is exposed, and a swapped
  literal fails **silently** — it simply never matches. Record all colours explicitly as
  v2 RGB, and never paste a colour out of a v1 example.
- **Prefer solid UI chrome over anything with the world showing through.** The user's own
  POE2 history is emphatic: both approaches he abandoned there died the same way — a
  threshold tuned on a clean sample collapsing against a busy animated background — and
  every tolerance he shipped ended up a live slider because a hard-coded default was twice
  wrong. This raises item 4 (lighting stability) from a nice-to-have to the main selection
  criterion for probe points.
- **Do not hard-code the reel zone's width.** It is a **rod stat**: 30% of the bar at 0
  Control, +1% per +0.01 Control, capped at 70%. Any signature that assumes a zone width
  breaks the moment the user changes rod (currently a Flimsy Rod). This constrains item 2's
  "minimum probe set" for `fish_on`.
- **Item 5 (is the cast meter camera-anchored) could not be closed by research** — the
  wiki's phrasing cannot distinguish the two cases, since the camera keeps the character
  centred either way. The cheap live test stands: cast, then pan the camera mid-cast and
  watch whether the meter moves. Note the stakes have dropped — perfect cast grants line
  **distance only**, no catch-rate or rarity benefit — so a camera-anchored meter now
  argues for dropping the feature rather than engineering around it.
- **`OSError` vs no-match.** v2 throws `OSError` when the screen capture itself fails, which
  is a different thing from a colour not being found. Keep the two apart when reporting
  tolerances, or a capture failure will read as "this signature does not work".

## Answer

> **⚠ CORRECTION — read this before using anything below**
>
> **Live verification on 2026-09-03 (later the same night) overturned three of the four
> signatures in the table below.** Everything below was derived from `screenshots/*.png`
> and is sound *about those images* — but the reference screenshots turned out to be an
> unsound basis for colour thresholds, because the live scene differs drastically from them.
>
> **The live-verified replacement is in the section "LIVE-VERIFIED SIGNATURE SET" at the
> bottom of this ticket. Use that. Treat the table below as superseded history.**
>
> What broke, and why:
>
> | Signature below | Live result | Root cause |
> | --- | --- | --- |
> | `casting` = bright pixel at (1116, 650), "margin 176" | **1/4 true positives, 18/93 false positives** | The probe sits on the **character's white glove**. Idle readings span min-channel 65..255; casting spans 94..212 — total overlap. |
> | `fish_on` = any dark pixel in the track band | **Fired 40/40 while idle** | It was measuring *scenery*. The reference shots had bright sand there; live at night the dock planking is dark, so "dark = track" matches everywhere. |
> | `bait` = cyan ring | **~60 false positives on idle frames** | Matched the bright blue **daytime sky**. The reference shot had a dark night sky. |
> | `success` = near-white in y 840..885 | untested live | — |
>
> The generalisable lesson, and it is the important output of this ticket:
> **the reference screenshots are usable for GEOMETRY — where UI elements sit — but not for
> COLOUR THRESHOLDS.** They are six frames from one time of day, one camera position, one
> hotbar layout, with no leaderboard panel and no `[AFK]` tag. Any threshold that touches
> scenery, or sits where the character can move, is fitted to that one scene and collapses.
> This is precisely the POE2 pitfall the research warned about, and it was walked into anyway.

**Originally recorded (superseded).** Every colour below was sampled with numpy/Pillow out of
`screenshots/*.png` and **cross-validated against all six frames**, so each signature is
checked for false matches against every other state rather than only its own.

Analysis scripts: `…\scratchpad\analyse.py`, `analyse2.py`, `analyse3.py` (+ `-report.txt`).
Two bugs were caught and fixed mid-analysis, both recorded in the pitfalls below.

Screenshots are 1920x1080 and the game runs at a 1920x1080 client at (0,0), so **image
coordinates equal screen coordinates** and no scaling was needed.

### The signature table

Proportions are of the client area, per the map's coordinate decision.

| Status | Test | Pixels (1920x1080) | Proportions | Expected | Tol |
| --- | --- | --- | --- | --- | --- |
| `casting` | one pixel is bright | (1116, 650) | 0.58125, 0.60185 | `0xE9E9DF`, or just `min(R,G,B) > 150` | 30 |
| `success` | any near-white in band | x 700..1250, y 840..885 | 0.36458..0.65104, 0.77778..0.81944 | `min(R,G,B) > 190` | — |
| `fish_on` | any dark pixel in the track | y 922, x 571..1349 | 0.85370, 0.29740..0.70260 | luma < 60 | 25 |
| `bait` | cyan ring somewhere | roams — region unknown | — | `0x62B3FF`-ish | 40 |
| `idle` | **nothing matches** | — | — | — | — |

### Why each works — with the measured margins

**`casting` — the strongest signature on the map.** A near-white vertical run sits at
**x 1112..1120, y 457..687** (9 columns wide, ~231 px tall). At (1116, 650) the reading is
`0xE9E9DF` while *every* other state reads `0x140B12`..`0x2F181B`. The **margin is 176**
between casting's dimmest channel and the brightest channel any other state shows there.
A plain brightness test separates it with enormous room to spare.

**`success` — clean and unambiguous.** Counting near-white pixels (`min > 190`) in
x 700..1250 by 10-pixel row bands:

| y band | idle | casting | bait | fish_on | fish_on2 | sucess |
| --- | --- | --- | --- | --- | --- | --- |
| 820..840 | 0 | 0 | 0 | **658** | **658** | 88 |
| **840..885** | **0** | **0** | **0** | **0** | **0** | **1317** |

The 820..840 band is contaminated by `fish_on`'s "Click & Hold Anywhere!" hint — so **use
y 840..885**, where success has 1317 white pixels and every other state has exactly zero.

**`fish_on` — the track is a dark trough.** Luma along y=922:

| state | x580 | x700 | x850 | x1000 | x1150 | x1300 |
| --- | --- | --- | --- | --- | --- | --- |
| idle | 104 | 105 | 106 | 109 | 115 | 116 |
| casting | 115 | 122 | 113 | 121 | 120 | 127 |
| bait | 118 | 120 | 110 | 120 | 116 | 129 |
| sucess | 108 | 118 | 113 | 120 | 108 | 115 |
| `fish_on` | **30** | **26** | 133 | 241 | **26** | **29** |
| `fish_on2` | 64 | 63 | **23** | **27** | **26** | **29** |

Non-fish states never leave the band **104..129**. Fish states read 22..30 on bare track,
~63 where the warm zone sits, or ~241 where the white zone sits. **Sample 4-5 points spread
across the track and call it `fish_on` if any reads luma < 60.** The zone caps at 70% of the
track width, so bare track is always visible somewhere.

**`bait` — the weak one.** Cyan pixel counts: `bait` **2551**, sucess 181, idle 136,
casting 14, fish_on 0. Separable in principle, but the ring **roams** (centred ~(1325,721)
in this frame) and AutoHotkey cannot count pixels cheaply. Since `PixelSearch` needs a
bounded region, this needs the roam area mapped live — and per the map's fog item, `bait`
may not need positive detection at all. **Treat this row as provisional.**

### Track and zone geometry — measured

- **Bar including end caps:** x 549..1369. **Inner track:** x **571..1349** (778 px wide).
- **Zone width: 231 px (`fish_on`) and 232 px (`fish_on2`)** = **29.7% of the track**. This
  independently confirms the wiki figure from [ticket 03](03-prior-art.md) — 30% of the bar
  at 0 Control — from pixels alone. Two sources agreeing is worth more than either alone.
- The zone is **split by two arrow glyphs** drawn inside it, so it reads as three fragments,
  not one run. Any detector must span from the first to the last fragment, not stop at the
  first.
- **Fish line: `0x434B5B`, 8-10 px wide, identical in both frames.** A distinctive blue-grey
  (B > G > R) against uniformly warm surroundings — so position tracking is viable as a
  fallback, not just the binary read.

### THE COLOUR-FLIP HYPOTHESIS IS CONFIRMED

The single most important result. Measured, not eyeballed:

| frame | zone colour | zone extent | fish centre | fish inside zone? |
| --- | --- | --- | --- | --- |
| `fish_on` | **`0xF1F1F1`** (neutral white, R−B = 0) | x 826..1057 | x 959 | **YES** |
| `fish_on2` | **`0x53372F`** (warm brown, R−B = +36) | x 572..804 | x 922 | **NO** |

White zone ↔ fish inside. Warm zone ↔ fish outside. So **one colour read anywhere in the
zone answers "am I on target?"** — no position maths needed. Handed to
[How the reel minigame gets steered](05-reel-steering-strategy.md), which this substantially
de-risks.

**Caveat, stated plainly: this is two frames.** It is strong evidence and it is consistent
with the mechanic, but it is not proof across many fish, lighting conditions or rods. Ticket
05 must still confirm it live.

### Tolerances — grounded, not guessed

Same-state frame pair (`fish_on` vs `fish_on2`), per-channel absolute difference:

| region | mean | p99 | max |
| --- | --- | --- | --- |
| hotbar strip (static UI) | 0.03 | 1 | **1** |
| sky (static scene) | 0.46 | 2 | 7 |
| whole frame | 3.37 | 46 | 237 |

Static UI in the PNGs is essentially perfect (max drift **1**). But **live reads are noisier
than the PNGs** — [ticket 01](01-can-ahk-see-roblox-pixels.md) measured ~8 of 72 points
shifting by >24 with no input at all. **Take the live figure as the floor: tolerance ≥ 25 for
anything with the game world behind it; ~15 suffices for solid UI chrome.** Every one of
these belongs on a slider anyway, per the POE2 lesson.

### Hotbar — corrected: it is NOT the clean three-way signal ticket 01 suggested

| state | near-white px in x 720..1200, y 1000..1080 |
| --- | --- |
| idle | 2466 |
| bait | 2465 |
| sucess | 2466 |
| `fish_on` / `fish_on2` | **599** |
| `casting` | **0** |

Ticket 01 read this live as "9 present / 0 absent" and I proposed a three-tier reading.
**Do not use the middle tier:** `fish_on`'s 599 pixels are the **"+20% Progress Speed"
caption**, which exists only while that buff is active. Without the buff it would read 0 and
be indistinguishable from `casting`. **Use the hotbar as a binary only** — present (>1500)
vs absent — and never as a `fish_on` tell.

### Item 6 — things that can cover a probe point

The Roblox **"Screenshot Taken" toast** occupies roughly **x 1700..1920, y 895..1000** and is
present in `casting.png`, `bait.png` and `fish_on2.png`. **No probe in the table above goes
near it**, but keep x > 1690 with y 890..1000 permanently off-limits. Player nametags sit
near screen centre around y 340..420 — also avoided.

### What is NOT answered here, and is now ticketed

- **Is the cast meter screen-fixed or camera-anchored?** One frame cannot tell. Graduated to
  [Is the cast meter's position fixed across casts?](13-cast-meter-fixed-position.md).
- **Do these night colours survive daylight?** Every screenshot is dusk. Graduated to
  [Do the measured signatures hold in daylight and on the live screen?](14-daylight-and-live-confirmation.md),
  which also covers PNG-vs-live drift.
- **Where the SHAKE ring can roam** — needs many live frames; folded into ticket 14.

## LIVE-VERIFIED SIGNATURE SET — measured 2026-09-03, use this one

Derived from a real fishing attempt on the user's own client, not from the reference
screenshots. **97 clean samples** spanning an in-game **night-to-day transition**, with the
player leaderboard panel open and the `[AFK]` tag showing — conditions none of the reference
screenshots contain.

Ground truth for `fish_on` was the agreement of three independent signals (hotbar hidden,
progress-bar near-white, and the fish line's `0x434B5B` at screen centre), so the labels are
not circular. Sample counts: **10 `fish_on`, 4 `casting`, 83 `idle`/`bait`**.

Raw data: `…\scratchpad\capture-log.txt`, scored by `…\scratchpad\final.py`.

### Scorecard

| Detector | True pos | False pos | Verdict |
| --- | --- | --- | --- |
| near-white in **progress-bar band** -> `fish_on` | **10/10** | 1/87 | **USE THIS** |
| **hotbar strip has no near-white** -> `casting` or `fish_on` | 10/10 + 4/4 | 0 | **USE THIS** |
| near-white in reel-track band -> `fish_on` | 5/10 | 0 | misses half — only fires when the zone is white (on target), so it is an *on-target* signal, not a *bar-present* signal |
| cast-meter probe bright -> `casting` | **1/4** | **18/93** | **UNUSABLE** |
| cyan ring found -> `bait` | — | ~60 on idle | **UNUSABLE as tuned** |

### The verified core

```text
progWhite = near-white present in client x 700..1240, y 970..995   (progress bar)
hotWhite  = near-white present in client x 700..1240, y 1000..1078 (hotbar strip)

fish_on  <=>  progWhite
casting  <=>  not hotWhite  and  not progWhite
idle     <=>  hotWhite      and  not progWhite   (and no success caption)
```

Both signals are **bright UI over dark chrome, at fixed screen positions**, which is exactly
why they survived the lighting swing. Near-white means `PixelSearch` for `0xFFFFFF` with
variation 40 (all channels >= 215).

### Why these two held while the others collapsed

Scenery-backed probe points swung wildly across the same run:

| point | max-channel range over the run |
| --- | --- |
| trackL (600, 922) | 17..135 |
| trackR (1300, 922) | 19..105 |
| progL (760, 982) | 19..255 |

Any absolute threshold on those is fitted to one moment. The two surviving detectors don't
test a scenery pixel at all — they ask whether a **bright UI element is rendered inside a
small fixed box**, which is a structural question, not a colour-matching one.

### Still unsolved, and honestly so

- **`bait` has no working detector.** Cyan matched the daytime sky ~60 times. Options: a much
  tighter blue-dominance test (the ring's `0x62B3FF` has B−R = 157; pastel sky is far lower),
  or skip detection entirely — see the map's fog on whether `bait` needs positive detection.
  **This is the main gap blocking a full loop.**
- **`success` is untested live.** Its band (x 700..1250, y 840..885) is the one with open
  world behind it, so it is the most exposed to daylight glare. Tracked in
  [ticket 14](14-daylight-and-live-confirmation.md).
- **The 1 false positive** on the progress-bar detector needs hardening: require the
  near-white to be horizontally extended (the bar is long and thin, scenery glare is not),
  or require two consecutive ticks to agree. Both are cheap.

### Confirmed unchanged from the screenshot analysis

- **Fish line is `0x434B5B`** — read live at screen centre during `fish_on`, exactly matching
  the PNG measurement. Geometry transfers; colour thresholds on UI chrome transfer.
- The reel bar and progress bar sit where the screenshots said. **Geometry was reliable; only
  colour thresholds were not.**

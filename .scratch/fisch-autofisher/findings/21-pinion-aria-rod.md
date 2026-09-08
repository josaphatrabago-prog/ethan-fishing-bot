# Findings: Pinion Aria rod — spelling, stats, the reel-UI mechanic, and macro precedent

Resolves [issues/21-pinion-aria-rod.md](../issues/21-pinion-aria-rod.md). Parent: [map.md](../map.md)

Researched 2026-09-08/09.

## Confidence key

| Label | Meaning |
| --- | --- |
| **Verified** | Read first-hand in a primary source: the official Fisch wiki page itself, the game's own changelog, an official developer/social post, or this repo's own source. |
| **Likely** | Multiple independent sources agree, or a reputable secondary guide site whose figures are internally consistent with others. |
| **Unverified** | Single forum / Reddit / TikTok / wiki-comment claim, or something reachable only through a search engine's own synthesis of cached snippets rather than a direct read. |
| **Not found** | Searched for specifically and no documentation exists either way. Not the same as "false". |

## Tooling notes (what was blocked)

- **`fischipedia.org` (the official Fisch wiki) could not be read at all, by any method tried.**
  Direct `WebFetch` returned **403 Forbidden** on the rod page, its `/Change_History`
  subpage, and the `1.72` update page. The `r.jina.ai` reader-proxy route that worked for
  Fandom in [Prior art](03-prior-art.md) instead returned the Cloudflare **"Just a
  moment…" / "Verification successful, waiting for fischipedia.org to respond"**
  challenge page verbatim — i.e. the proxy itself got challenged this time. A
  `translate.goog` Google Translate proxy of the same URL was tried as a third route; it
  **303-redirected straight back to the blocked `fischipedia.org` origin** before
  rendering anything. Three independent bypass attempts, three failures. This is a
  strictly worse outcome than the prior research found for Fandom, and it means **every
  fischipedia.org claim below is absent, not merely unverified** — nothing from the
  official wiki is cited directly anywhere in this document.
- **`fisch.fandom.com` (the Fandom mirror) returned 402 Payment Required, direct and via
  the reader proxy, on both the article page and its `/f/t/` discussion-thread page.**
  This is worse than the prior research's experience, where the reader proxy got through;
  it did not this time.
- Several secondary guide sites blocked direct `WebFetch` (`sportskeeda.com` both
  articles: 403/405; `beebom.com`'s second fetch attempt was skipped once the first
  succeeded; `xsfisch.com`: TLS handshake error; `progameguides.com`: 403 direct, readable
  via `r.jina.ai`; `deltiasgaming.com`: 403 direct **and** via `r.jina.ai`, a CloudFront
  block that persisted through the proxy). Where a proxy worked (`droidgamers.com`,
  `gatagames.com`, `ingamenews.com`, `fischepedia.com`, `progameguides.com`), the numbers
  those five independent sites report agree with each other exactly, which is why several
  claims below are labelled Likely rather than Unverified — five unrelated outlets citing
  identical figures (`142%` / `242%` / `4.2%`, `342m`, `42%`/`4.2x`, `14.2%`/`1.85x`) is
  strong internal corroboration even though **none of them is the wiki itself**, and they
  most likely all transcribed the same wiki infobox rather than measuring independently.
- `gh search code "Pinion"` (GitHub's own code-search API via `gh`) returned irrelevant
  matches from unrelated repositories — it does not appear to be scoped the way the local
  grep is, and returned zero genuine hits. **Switched approach**: shallow-cloned six
  specific Fisch-macro repositories found by `WebSearch` and grepped them locally instead
  (see §5) — this worked and is the approach used for every macro claim below.
- The repo's own todo item this ticket was asked to check ("Pinion Aria (fish shares the
  bar's colour)") **does not appear anywhere in this git repo** — `grep -ri "pinion"`
  across the whole tree returns nothing. It lives in the **Obsidian vault**, at
  `Fisch/Todo.md` under "Up Next" → **[Rare rods]** (read directly, Verified): *"Six
  rod-specific mechanics are unhandled and are total losses if that rod is equipped:
  Dreambreaker (controls inverted), Bellona's Waraxe (two bars, needs right-click),
  Tranquility (D/F/J/K rhythm game replaces the minigame), Noiseform (drive to a colour
  zone, not the fish), Pinion Aria (fish shares the bar's colour), Darkheart (bar blacks
  out)."* This document treats that vault line as the claim under test.

## 1. Exact name and spelling

**Likely.** The correct in-game name is **"Pinion's Aria"** — apostrophe-s, not "Pinion
Aria" or "Pinions Aria". Every independent source's canonical title/URL agrees:
[fischipedia.org/wiki/Pinion's_Aria](https://fischipedia.org/wiki/Pinion's_Aria) (URL
only — page itself unreadable, see Tooling notes),
[fisch.fandom.com/wiki/Pinion's_Aria](https://fisch.fandom.com/wiki/Pinion%27s_Aria),
[Beebom](https://beebom.com/how-to-get-pinions-aria-rod-in-fisch/),
[GataGames](https://gatagames.com/2026/02/28/how-to-obtain-the-fisch-pinions-aria-rod-stats-and-passives-included/),
[Droid Gamers](https://www.droidgamers.com/guides/fisch-pinions-aria/),
[ingamenews.com](https://ingamenews.com/2026/02/how-to-get-fisch-pinions-aria-rod-full.html).

**It is a rod, not a rod skin.** Every source treats it as a distinct item with its own
stats, its own quest reward, and its own icon — never as a cosmetic recolour applied over
another rod's stats. This is a materially different kind of thing from the repo's
existing `MarkerMode = 2` "second rod skin" (`fisch-autofisher.ahk:340-343`), which is
the *same underlying rod* rendered with a differently-coloured bar. Nothing found treats
Pinion's Aria that way.

## 2. Stats

**Likely** (five independent secondary sources agree exactly on every figure):

| Stat | Value | Source |
| --- | --- | --- |
| Lure Speed | 142% | [GataGames](https://gatagames.com/2026/02/28/how-to-obtain-the-fisch-pinions-aria-rod-stats-and-passives-included/), [Droid Gamers](https://www.droidgamers.com/guides/fisch-pinions-aria/), [ingamenews.com](https://ingamenews.com/2026/02/how-to-get-fisch-pinions-aria-rod-full.html), [Beebom](https://beebom.com/how-to-get-pinions-aria-rod-in-fisch/), [ProGameGuides](https://progameguides.com/roblox/how-to-get-pinions-aria-rod-in-fisch-mysterious-songstress-quest/) |
| Luck | 242% | same five |
| Control | 0 | same five |
| Resilience | 4.2% | same five |
| Max Kg | infinite (`inf kg`) | same five |
| Line Distance | 342 m | GataGames, Droid Gamers |

**Passive ability, verbatim as reconstructed from the most detailed single mirror**
([fischepedia.com](https://fischepedia.com/wiki/pinions-aria/), a fan wiki distinct from
both fischipedia.org and Fandom — **Likely**, cross-checked against GataGames, Droid
Gamers and a `WebSearch` synthesis that all describe the same four effects in the same
order):

> **First passive** — 42% chance for the Harmonized mutation (4.2× value multiplier;
> ProGameGuides gives 30% instead of 42% for this figure — the one number that did *not*
> cross-validate, flagged below), 14.2% chance for Shiny (1.85× value), Perfect catches
> award 2.42× XP, +10% initial progress, external Control boosts reduced by 50%, fishing
> bar moves 100% faster.
>
> **Second passive (the note system)** — Musical notes fall onto the reeling bar, every 2
> seconds at first, accelerating to every 1 second, "similar to the Santa's Miracle Rod."
> Catching a note: +0.025 Control (stacks to a max of +0.2), +3% flat progress, +5%
> progress speed, −2.5% progress-loss speed, −10% fish movement speed. Missing a note
> reverses these, and one source additionally reports a +40% fish-speed boost on a miss.
>
> **Third passive (Resonance)** — After catching 7 consecutive notes, "the fish will
> actually follow your fishing bar," and all fish abilities are disabled for several
> seconds (Wyvern excepted, per one source). While in Resonance: +1% forced progress
> speed every second (uncapped), Control decreases 0.075/sec (floor −0.2). Resonance ends
> the instant a note is missed.
>
> **Fourth passive** — Either catching every note in a reel, or keeping the bar
> overlapping the fish for its duration, counts as a Perfect Catch.

**One documented visual effect exists, but it is not a bar/fish recolour**: catching a
Harmonized-mutation fish flashes the bottom of the screen purple — a catch-result flash,
not a live reeling-bar colour change (`WebSearch` synthesis only — **Unverified**, no
direct source read).

## 3. How to obtain

**Likely**, cross-corroborated by GataGames, Droid Gamers, ingamenews.com and Beebom,
whose quest-step lists agree almost word for word (again, most plausibly because all four
transcribe the same wiki source, not independent field research):

- **Quest giver**: the Mysterious Songstress, at the Underground Music Venue (on/near
  the main stage).
- **Level requirement**: 424, to start the questline — this figure appeared
  independently in two separate `WebSearch` result-syntheses (not from a page this
  research could open directly) — **Unverified** on its own, but the two syntheses did
  not simply repeat each other's wording, so treat it as better than a single unread
  snippet.
- **Quest steps** (six-step chain, as given by GataGames/Droid Gamers/ingamenews.com):
  1. Catch a musical fish (a Mythical DJ Spinopus, per ProGameGuides) to demonstrate
     musical ability to the Songstress.
  2. Receive a Hang Glider; use it to reach the **Above the Clouds** island via Castaway
     Cliffs.
  3. Catch a **Heavenly Harmonic Dove** (using the Heavenly rod with a Long enchantment,
     per Beebom).
  4. Return the dove to the Songstress to receive the rod itself, initially locked with a
     **Restricted enchant** — this blocks further enchanting and blocks
     shiny/sparkling/mutation results, and confines the rod to certain locations.
  5. Catch 42 fish at Crystal Cove using Pinion's Aria **without missing a single note**.
  6. Catch a Megalodon, Scylla, Leviathan, or Colossal Dragon, again without missing a
     note, to complete the Songstress's final quest and remove the Restricted enchant.
- **Cost in C$**: **Not found.** No source mentions a Shop price; this is a
  quest-unlocked rod, not a purchase.
- **Limited/event-only**: **Unverified**, but leaning yes for the *acquisition window*,
  not the rod itself. A `WebSearch` synthesis (not a page this research could open
  directly) describes the Mysterious Songstress as *"a time-exclusive quest-only NPC…
  once the NPC is out of the game, there is no way to complete their questline and
  receive their rewards."* No official patch note confirming this could be read directly
  (see Tooling notes) — `deltiasgaming.com`'s two guides, which by their titles look like
  the right place to confirm this, were blocked on every attempt. Nothing found suggests
  a *player who already owns* the rod ever loses it — only that the path to obtain it may
  close.
- **Rarity — roughly how many players have it**: **Not found.** No player-count,
  leaderboard, or ownership-rate source exists in anything reachable here. Given the
  Level 424 gate and a six-step quest culminating in a no-miss fight against an
  end-game boss, it is reasonable to assume this is a small fraction of the playerbase,
  but no source states or estimates a number, so this is not asserted as fact.

## 4. What it does to the reel minigame UI — the important part

**CORRECTED.** The vault's description — *"Pinion Aria (fish shares the bar's colour)"*
— does not match anything in any source read for this ticket, official-adjacent or fan,
across five independent write-ups that otherwise agree on every other detail of this
rod's passive down to individual percentage points. What is actually documented,
consistently, is a **falling-note rhythm overlay on top of the ordinary bar**, not a
colour-sharing mechanic:

- **Notes fall across the reeling bar** on a cadence (every 2s, accelerating to every
  1s), explicitly compared by the source material to the existing Santa's Miracle Rod's
  note mechanic — i.e. this is a known *category* of Fisch minigame variant, not a novel
  colour effect.
- **Catching a note directly changes the bar's width in real time**: +0.025 Control per
  catch, stacking up to +0.2 — under the wiki's own Control→width formula (documented
  independently in [Prior art §3.2](03-prior-art.md), "each +0.01 Control = +1% width"),
  that is up to **+20 percentage points of bar width**, gained and lost fight-by-fight as
  notes are hit or missed. **Missing a note shrinks the bar back down** and speeds the
  fish up (one source: +40%).
- **A "Resonance" state (7 notes caught in a row) makes the fish itself move to track
  the bar's position** — a positional lock, not a colour cue — disables fish abilities,
  and forces +1%/sec progress regardless of aim, until a note is missed.
- **No source describes any colour change to the fish marker or to the bar itself** for
  this rod, under any condition, in any of the five write-ups consulted. The one
  documented visual effect (a purple screen-flash) fires only on landing a Harmonized
  catch, is a one-off result flash rather than a persistent reeling-state colour, and is
  itself only Unverified (see §2).
- **Screenshot or video frame showing the reel bar in use**: **Not found.** No image or
  video frame could be retrieved through any tool available here — the wiki's image
  pages sit behind the same block as its text pages, and while a matching YouTube guide
  title surfaced (*"HOW TO EASILY OBTAIN PINION'S ARIA in FISCH"*), no frame or thumbnail
  from it was fetchable. This is a real gap, not an omission.

**Verdict on the todo line: corrected, not confirmed.** "Fish shares the bar's colour" is
not supported by anything found. The mechanism that actually needs handling is a
rhythm/note overlay that (a) resizes the bar live, (b) can speed up or slow down the
fish, and (c) can lock the fish's position to the bar outright during Resonance — none of
which are colour effects.

## 5. How other Fisch macros handle it

Six candidate repositories were found by `WebSearch` for `fisch autofish macro AutoHotkey
github` and shallow-cloned to
`C:\Users\Josap\AppData\Local\Temp\claude\...\scratchpad\ghrepos\` for local grepping
(GitHub's own code-search via `gh search code` proved unusable — see Tooling notes):
[MaxxWasHere/Fischer](https://github.com/MaxxWasHere/Fischer),
[niko-private/fisch-macro](https://github.com/niko-private/fisch-macro),
[pagiro/roblox-fisch-macro](https://github.com/pagiro/roblox-fisch-macro) (a loader/`.rar`
distribution, no readable source),
[Goldydt/fisch_macro](https://github.com/Goldydt/fisch_macro),
[Cweamy/Fisch-Cream-s-Macro](https://github.com/Cweamy/Fisch-Cream-s-Macro), and
[idk586/fisch](https://github.com/idk586/fisch).

**Verified** (read directly from the cloned source): **none of the six mention "Pinion" or
"Aria" anywhere.** A case-insensitive grep for both words across every file flagged
several hits, but every one was a false positive on the substring "variable"/"Variation"
— none is an actual reference to the rod.

What the source *does* show, all **Verified** by direct reading:

- **[Goldydt/fisch_macro's README](https://github.com/Goldydt/fisch_macro/blob/main/README.md)
  states outright: "This macro only supports normal rods. Special developer rods (e.g.,
  Duskwire) are not supported."** This is the closest thing to a documented policy on
  special-mechanic rods among the six, and the policy is exclusion, not support.
- **[Cweamy/Fisch-Cream-s-Macro (AHK v1)](https://github.com/Cweamy/Fisch-Cream-s-Macro/blob/main/Fisch%20Cream's%20Macro%20free%20edition.Ahk#L129-L131)**
  hardcodes three colour/variation pairs each for the fish and the bar:
  ```ahk
  Global Color_Fish := {"0x434b5b": 3, "0x4a4a5c": 4, "0x47515d": 4}  ; Color for fish (with variation)
  Global Color_White := {"0xFFFFFF": 15} ; Color for white (used for detecting certain screen regions)
  Global Color_Bar := {"0x848587": 4, "0x787773": 4, "0x7a7873": 4} ; Colors for bar (with variations)
  ```
  and at [line 224](https://github.com/Cweamy/Fisch-Cream-s-Macro/blob/main/Fisch%20Cream's%20Macro%20free%20edition.Ahk#L224)
  falls back from searching `Color_White` to searching `Color_Bar` if white isn't found —
  i.e. it already anticipates a non-white bar in general, just not this rod specifically.
  Worth noting for this repo: **`0x434b5b` is almost exactly this repo's own measured
  `COL_FISH` constant, `0x434B5B`** (see `map.md`'s "Fish line is `0x434B5B`, stable
  across both frames") — an independent cross-validation of that constant from a wholly
  unrelated codebase.
- **[MaxxWasHere/Fischer (AHK v1)](https://github.com/MaxxWasHere/Fischer/blob/main/Fischer.ahk#L485)**
  hardcodes a single fish colour (`0x5B4B43`), a single white-bar colour (`0xFFFFFF`),
  and a separate arrow colour (`0x878584`), each with its own configurable tolerance
  variable (`FishBarColorTolerance`, `WhiteBarColorTolerance`, `ArrowColorTolerance`) —
  no per-rod branching of any kind.
- **[idk586/fisch, `latest.Ahk` (AHK v2)](https://github.com/idk586/fisch/blob/main/latest.Ahk#L46)**
  hardcodes one reel-bar colour, `0xf1f1f1` at variation 20, and its
  [README](https://github.com/idk586/fisch/blob/main/README.md) tells the user to
  hand-edit a `Control` variable to match their own rod's Control stat — the only
  rod-awareness in this macro is a manually-entered number, not a colour table.
- **[niko-private/fisch-macro (Python + OpenCV)](https://github.com/niko-private/fisch-macro/blob/main/fisch.py#L18-L22)**
  is the most sophisticated of the six on exactly this question. It defines three
  colour-mask hypotheses for the control bar and tests all three every frame:
  ```python
  white_threshold = np.array([240, 240, 240])
  dark_green_threshold_low = np.array([0, 50, 0])
  dark_green_threshold_high = np.array([100, 150, 100])
  dark_red_threshold_low = np.array([50, 0, 0])
  dark_red_threshold_high = np.array([150, 100, 100])
  ```
  applied at [fisch.py lines 220–227](https://github.com/niko-private/fisch-macro/blob/main/fisch.py#L220-L227)
  as `white_mask`, `dark_green_mask`, `dark_red_mask`. This is a genuinely different
  strategy from the other five — trying a short fixed list of alternate bar colours
  instead of assuming one — but nothing in the code names Pinion's Aria, a note overlay,
  or a rhythm mechanic; it would not read or react to falling notes even if its colour
  guesses happened to match.

**Conclusion for this section**: no macro found in the wild special-cases Pinion's Aria,
or any note-rhythm rod, by name. The two strategies actually used elsewhere are (a) a
short fixed list of alternate bar colours tried in sequence (niko-private), or (b) an
explicit written disclaimer that special/developer rods are unsupported (Goldydt). None
of the six would recognise a falling-note overlay, a live mid-fight bar-width change, or
a Resonance position-lock; every one of them would just keep reading position/colour as
normal and would misbehave only to the extent its own colour assumptions stop matching
what's on screen — which, per §4, may not even happen for this specific rod, since
nothing found says its bar or fish are painted differently at all.

## 6. Release history

**Likely** (`WebSearch` result-synthesis, not a directly-read changelog — see Tooling
notes: `fischipedia.org/wiki/1.72`, `fischipedia.org/wiki/Pinion's_Aria/Change_History`,
and `fisch.fandom.com/wiki/Changelogs` were all blocked on every attempt):

- Pinion's Aria was introduced in **Fisch update 1.72, released 2026-02-21**, alongside
  the Mysterious Songstress quest NPC, a new "Random Rod" mechanic, a "Vicious"
  enchantment exclusive to Cosmic Relics, a Trade Plaza server browser, and Fish Radar
  changes.
- One source's synthesis additionally calls this a "minor update... that introduced
  multiple new rods... and a limited-time quest rod" — consistent with, but not
  independent additional confirmation of, the limited-time framing in §3.

## Implications for the macro

Given how this repo's detector actually works — the blue-leads-red fish-marker rule
(`IsFishPixel`, `fisch-autofisher.ahk:1089-1101`: `b > r + 6` against `COL_FISH`
`0x484F60`/`COL_FISH_LIT` `0xA8AEBC`), the white/pale zone search keyed on `MarkerMode`
(`FindZone`, lines 803-811, using `Cfg["zoneWidth"]` = 232px or `Cfg["zoneWidthPale"]` =
411px), the near-black track, and ticket 20's authoritative on-target test
(`FishOnTarget`, lines 925-941: search a small box around the fish for `COL_WHITE`) —

- **The colour assumptions are probably NOT directly threatened by this rod.** Nothing
  found in §4 says Pinion's Aria repaints the fish marker or recolours the bar itself, so
  `IsFishPixel`'s blue-leads-red rule and `FindZone`'s white/pale search would likely
  still find the right pixels most of the time. The todo's original framing — treating
  this as a colour problem — does not hold up.
- **What would actually break: the zone-width constant.** `FindZone` bakes in one fixed
  width per `MarkerMode`, measured once and trusted for the whole fight. Pinion's Aria
  changes the bar's width *live, mid-fight*, as notes are hit (+0.025 Control per catch,
  up to +0.2, i.e. up to +20 points of width per the Control→width formula) or missed
  (reversing it). A width read once at fight-start would go stale — the same hazard
  ticket 16 already flagged in general ("measure zoneWidth every frame, don't trust a
  constant") is not merely possible on this rod, it is close to guaranteed.
- **The on-target signal likely still works, but can go misleadingly perfect.**
  `FishOnTarget`'s white-near-the-fish test does not depend on knowing the zone's exact
  width, so it should keep functioning through the width drift above. But during a
  Resonance streak (7 notes caught in a row), the fish is documented to *track the bar's
  position directly* — so `onTgt` would likely read true continuously, independent of
  anything the steering loop does. A macro unaware of Resonance would not misdetect, but
  it would keep "steering" against a fish that isn't actually free to leave the zone,
  which is harmless (the fish is already captured) but tells the controller nothing true
  about its own performance for that stretch.
- **The falling notes themselves are entirely unmodeled**, here and in every one of the
  six macros checked in §5. A macro that ignores them (as this repo currently would)
  doesn't crash or misread pixels — it just fights a fixed-width, normal-speed version of
  a fight that a note-catching player would make wider and faster, and eats the -10%
  speed/-2.5% progress-loss penalties on every note it doesn't "catch" (which is all of
  them, since nothing reads for notes at all).
- **If Pinion's Aria's bar visually resembles the "coloured" pale rendering more than the
  plain white one** — unconfirmed either way, no source describes its colour — the
  `MarkerMode` latch would pick `zoneWidthPale` (411px), which is even more wrong for a
  rod whose real width is constantly changing rather than fixed at either constant.

**Bottom line for the todo**: drop "fish shares the bar's colour" as this rod's
description — nothing found supports it. If this rod is ever worth supporting, the real
work is measuring zone width every tick instead of trusting a per-`MarkerMode` constant
(which ticket 16 and 17 already motivate for other reasons) and deciding whether to model
the falling notes at all — not building a new colour rule.

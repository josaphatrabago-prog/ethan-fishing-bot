# Pinion Aria rod: spelling, stats, obtain method, reel-UI mechanic, and macro precedent

Type: research
Status: resolved
Blocked by: —
Parent: ../map.md
Label: `wayfinder:research`

## Question

"Pinion Aria" (the user typed "pinions aria") is a fishing rod in Fisch, and the vault's
`Fisch/Todo.md` "Rare rods" item describes it as one of six rod-specific mechanics this
script does not handle, with the one-line gloss "fish shares the bar's colour." Find out,
with a cited source for every claim:

1. **Exact name and spelling** ("Pinion Aria" vs "Pinions Aria" vs "Pinion's Aria"), and
   whether it is a rod, a rod skin, or both.
2. **Stats**: Lure Speed, Luck, Control, Resilience, Max Kg, and its **passive ability**
   text verbatim.
3. **How to obtain**: location, cost (C$), quest steps, level/progression requirements,
   whether it is limited/event-only, and roughly how many players realistically have it.
4. **What it does to the reel minigame UI** — the most important part. Precisely what
   changes on screen while reeling with this rod: fish-marker colour, player-bar colour,
   track colour, constant vs randomised, visual-only vs also changing bar width/speed. If
   a screenshot or video frame exists showing the reel bar with this rod, describe and
   link it. **Confirm or correct** the vault's "fish shares the bar's colour" gloss.
5. **How other Fisch macros handle it** — search GitHub for open-source Fisch
   macros/autofishers and grep their source for "Pinion", "Aria", or any rod-specific
   colour setting, quoting the relevant constants/logic with a link to the file and line.
6. **Release history**: which Fisch update added it and when.

## Answer

Full findings, with a source and confidence level per claim:
**[findings/21-pinion-aria-rod.md](../findings/21-pinion-aria-rod.md)**

The correct name is **"Pinion's Aria"** (apostrophe-s), a standalone rod rather than a
skin over another rod. Stats: Lure Speed 142%, Luck 242%, Control 0, Resilience 4.2%, Max
Kg infinite. Obtained via a six-step "Mysterious Songstress" questline at the Underground
Music Venue (no C$ cost; likely a time-limited quest window, introduced in update 1.72,
2026-02-21). **The vault's "fish shares the bar's colour" gloss is corrected, not
confirmed**: no source, official or fan, describes any colour change to the fish marker
or bar for this rod. What it actually does is overlay a falling-note rhythm minigame that
resizes the reel bar live (±20 points of Control/width per note hit or missed) and, after
7 notes caught in a row, locks the fish's *position* to the bar during a "Resonance"
state — a geometry and timing effect, not a colour one. None of six inspected
open-source Fisch macros special-case this rod; the closest precedent is one macro
(Cweamy's) trying a short fixed list of alternate bar colours as a fallback, and another
(Goldydt's) explicitly disclaiming support for special/developer rods altogether.

The official `fischipedia.org` wiki and the Fandom mirror were both completely
unreadable across every method tried (Cloudflare challenge, 402 Payment Required,
reader-proxy, and a Google-Translate-proxy redirect) — see the findings file's "Tooling
notes" section. Every claim above rests on 4–5 mutually-consistent secondary guide sites
instead, so it is labelled Likely rather than Verified throughout.

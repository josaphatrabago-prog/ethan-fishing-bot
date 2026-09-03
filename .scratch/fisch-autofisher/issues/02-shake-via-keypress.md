# Answer SHAKE with a keypress

Type: task
Status: resolved
Blocked by: —
Parent: ../map.md
Label: `wayfinder:task`

HITL — the human flips an in-game setting and reports what happens.

## Question

Can the `bait` phase be cleared entirely by keyboard, with no screen search at all — and if
so, what exact key, and what cadence clears a full shake phase?

Charting settled that SHAKE is answered by keypress rather than by hunting the roaming
circle. Fisch is understood to have a shake input setting with a keyboard/navigation option
that makes the SHAKE prompt respond to Enter. That belief needs confirming on the user's
own client before the loop depends on it.

## What to determine

1. **Find the setting.** Locate Fisch's shake input option (Settings → shake mode, or
   similar). Record its exact name, its options, and which one enables keyboard answering.
   Set it, and note it as a prerequisite the script must document — the script cannot set it.
2. **Confirm the key.** Verify Enter actually clears a SHAKE prompt. If it is a different
   key, record the real one.
3. **How many, how fast.** A cast requires several shakes, not one. Determine:
   - roughly how many prompts appear per cast, and whether the count varies
   - the fastest press cadence the game still accepts (does spamming get swallowed or
     rate-limited?)
   - whether presses land *before* a prompt appears — i.e. is blind continuous spamming
     safe, or does an early press get eaten and cost a prompt?
4. **Any side effects of blind spamming.** Enter is also the Roblox chat key. Confirm that
   spamming it does not open the chat box, send messages, or steal focus — that would break
   everything downstream. If it does, find a key that does not.
5. **How the phase ends.** Note whether there is any visible signal that shaking is
   *finished*, other than the reel bar appearing.

## Why this unblocks a decision

The answer decides whether `bait` needs positive pixel detection at all. If blind spamming
is safe and side-effect-free, the script can simply press the key whenever `Status` is not
`casting` / `fish_on` / `success`, and one whole detection signature disappears from the
map. That fog patch is recorded on the map under Not yet specified.

## Research input from [ticket 03](03-prior-art.md)

**Item 1 is answered, and the premise was wrong. There is no Fisch shake setting.** The
keyboard route is Roblox's **platform-wide UI Selection Toggle** accessibility feature:

- `\` toggles UI Selection on
- arrow keys move a highlight between UI elements
- **Enter activates the highlighted element**

So the decision survives but the mechanism differs, with three consequences to work through:

1. **`\` becomes a prerequisite** the script must document and cannot set itself — same
   class of prerequisite the original ticket anticipated, different key.
2. **The highlight is shared, stateful UI.** Enter activates *whatever is currently
   selected*, which is not necessarily the SHAKE button. This is the real risk here, and it
   is why the map's fog item on `bait` detection has moved toward "yes, positive detection
   is needed". Determine: does the SHAKE prompt auto-take the highlight when it appears? If
   not, does it need an arrow press first, and is that stable?
3. **Item 4 gets sharper, not softer.** Enter is Roblox's chat key *and* now a UI activator.
   Test specifically whether blind spamming can activate some other highlighted element —
   a menu button, the Shop, the Bestiary — which would be far worse than merely opening chat.

If the highlight cannot be relied on, note it plainly: the fallback is the visually-hunted
SHAKE circle, which is currently ruled out of scope on the map and would have to be brought
back in.

## Answer

> **REOPENED AND RESOLVED THE OTHER WAY, later on 2026-09-03.** The user corrected
> the conclusion below from their own knowledge of the game: *"the shake is not
> perfect. you can just send enter key when shake appears its much easier."* They
> were right, and it is now the shipped behaviour.
>
> **Pressing Enter answers a SHAKE prompt directly.** No accessibility toggle was
> needed, and no chat box opens — verified by screenshotting the game after a
> 150-second run of nothing but Enter presses. Measured against the clicking
> approach it is also slightly better, and much simpler:
>
> | Method | Hooks/min | Shakes per hook |
> | --- | --- | --- |
> | Click the ring | 2.15 | 44 |
> | **Enter key** | **2.42** | **39** |
>
> Clicking required estimating the ring's centre from a `PixelSearch` hit near its
> top edge — an offset guess — and it dragged the cursor away from the game area
> between prompts. A keypress has neither problem.
>
> The ring detector is **kept**, but only to decide *whether* a prompt is on screen.
> With Enter, its exact position no longer matters. Clicking remains available as a
> fallback via the "Answer SHAKE with the Enter key" checkbox.
>
> **Why the original reasoning went wrong:** the research in
> [Prior art](03-prior-art.md) found no Fisch shake setting and concluded Enter must
> therefore work through Roblox's `\` UI Selection Toggle, whose shared highlight
> would make it unreliable. That inference was plausible and false — Fisch answers
> Enter directly. A user who plays the game outranks an inference drawn from an
> absence of documentation.

### Superseded conclusion, kept for the record

**CLOSED 2026-09-03 as superseded, not resolved.** The keypress route was never needed.

Research first undermined the premise: there is no Fisch shake setting, only Roblox's
platform-wide UI Selection Toggle (the `\` key), whose highlight is *shared stateful UI* — so
Enter activates whatever happens to be selected, which is not necessarily the SHAKE button.

Then the very alternative this ticket existed to avoid turned out to work perfectly. A strict
colour test for the ring — `0x6CBEFF` with variation 40, which in effect demands a blue
channel of at least 215 — separates the ring from even a bright daytime sky, because the
ring's blue is saturated (B−R = +135..+159) while pastel sky sits at B−R = +9..+48. Validated
across 90 live frames spanning night and day: **54/54 frames containing a visible ring were
detected, with zero false positives.** The shipped script clicks the ring and logged **350
successful shakes** in a single 240-second run.

So `bait` is handled visually after all — no in-game setting to change, and no risk of Enter
opening the chat box. The map's Out-of-scope entry for visual ring hunting is reversed
accordingly, on the exact condition it was originally filed under.

**Worth keeping:** an earlier, looser cyan test (`0x62B3FF` ±42 over a wide box) matched the
daytime sky and produced ~60 false positives, which caused 39 stray clicks in an early
capture run. The strictness *is* the trick — do not widen this tolerance without
re-validating against a daylight sky.


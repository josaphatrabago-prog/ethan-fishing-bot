# A stale settings file silently overrides improved defaults

Type: task
Status: resolved
Blocked by: —
Parent: ../map.md
Label: `wayfinder:task`

AFK. Small, self-contained, and found by testing rather than by reasoning.

## Question

How should the settings file handle defaults that have improved since it was written?

## The bug, observed

While building the script on 2026-09-03, `tolFish` was tightened from 30 to 18 in source
because 30 was matching scenery. Subsequent runs kept using **30**: an INI written by an
earlier run held the old value, `LoadSettings()` applied it over the new default, and nothing
in the log or the window indicated it. A source-level improvement was silently reverted by a
file, and it took a puzzled look at the INI to notice.

This is the same class of failure as the POE2 lesson in [Prior art](03-prior-art.md) — a
value that looks configured but is actually stale — and it will bite every future tuning
change, including the ones [Tune it against a live session](12-tune-against-live-session.md)
is about to produce.

## What to decide and implement

1. **Stamp a settings version** in the INI (`[meta] settingsVersion=N`), bumped in source
   whenever a default changes meaningfully.
2. **Decide the policy on a version mismatch.** Options, roughly in order of preference:
   - keep the user's value but **flag it visibly** as differing from the shipped default
   - migrate known keys, resetting only those whose defaults changed
   - ignore the stale file entirely and say so plainly in the log

   Pick deliberately. The user explicitly asked for tunability, so silently discarding their
   hand-tuned values would be its own bug — but silently keeping a stale value is the bug
   this ticket exists to fix. Flagging satisfies both.
3. **Show provenance in the window.** The calibration panel should be able to say which
   values came from the file and which are shipped defaults, so "did my tuning actually
   save?" is answerable without opening the INI.
4. Add the **Reset to defaults** control that ticket 09's original spec called for and the
   built window does not yet have.

## Answer

**Resolved on 2026-09-03**, after the bug recurred: the settings file on disk pinned
`reelDampMs=150`, left over from the abandoned click-rate experiment, against a shipped default
of 40 — and still carried dead `clickMax`/`clickNeutral` keys. It had been saved that morning,
so the new control law would have run with 150 ms of damping and nothing would have said so.

### The policy chosen

Option 2 from the list above — **migrate known keys, resetting only those whose defaults
changed** — not option 3. Discarding the whole `[tuning]` section was implemented first and then
rejected on this ticket's own reasoning: the user explicitly asked for tunability, so silently
throwing away hand-tuned values is its own bug.

Making that distinction possible needs **provenance**, so `SaveSettings` now writes a
`[defaults]` section recording the shipped default each value was saved against. On load:

| Case | Behaviour |
| --- | --- |
| Same `settingsVersion` | Load verbatim. |
| Version bump, saved value **differs** from the default it was saved against | The user tuned it deliberately — **keep it**, and report it in the log. |
| Version bump, saved value **equals** the default it was saved against | Never touched — **adopt the new default**, and report it. |
| No `[defaults]` section at all (pre-provenance file) | Provenance unknowable, so the `[tuning]` section is dropped and the log says so. `[boxes]` still loads: screen geometry stays valid across versions. |

`SETTINGS_VERSION` is 3. `[boxes]` is deliberately never version-gated.

### Verified, not assumed

Three fixtures, each run headless through `selftest` so the resulting tuning could be read back:

| Fixture | Expected | Got |
| --- | --- | --- |
| The real stale file (no version, no provenance) | tuning dropped, `reelDampMs` back to 40 | **40** |
| v3 file + copy bumped to v4 with `reelDeadPx` default 70→55; user had tuned `tolWhite` 40→55 | `tolWhite` kept at 55, `reelDeadPx` moves to 55 | **`tolWhite=55`, `reelDeadPx=55`** |
| Same file stamped as the current version | verbatim: `tolWhite=55`, `reelDeadPx=70` | **verbatim** |

### Items 3 and 4

- **Provenance in the window** — satisfied lightly: the log reports `kept your tuning: …` and
  `updated to new defaults: …` at startup, so "did my tuning survive?" is answerable without
  opening the INI. A per-slider provenance marker was judged more furniture than it is worth.
- **Reset to defaults** — added, next to *Test detectors*. It puts every value back, updates the
  sliders and checkboxes so the panel cannot misreport what is in effect, and saves.

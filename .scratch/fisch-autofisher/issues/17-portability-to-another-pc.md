# Will this run on a different PC?

Type: task
Status: resolved
Blocked by: 11
Parent: ../map.md
Label: `wayfinder:task`

Raised by the user: *"now i want to use this on a separate pc. can you make sure i will not
have any issues when I use it in a different machine"*

## Question

What in the script is tied to this particular machine, and what breaks elsewhere?

## What was found

### A real bug: lengths were never scaled, only positions

`SX()`/`SY()` converted reference coordinates to screen coordinates, so every *position*
scaled with the window. But every *length* was left in reference pixels and compared
directly against screen-pixel measurements:

- `ZONE_W_MIN` / `ZONE_W_MAX` against a measured zone width
- `reelDeadPx` (70) against a measured aim error
- the `+6` / `+24` search skips, the fish/zone velocity clamps, and `jump < 300`

At 1920x1080 the scale factor is exactly 1.0, so these coincided and the bug was invisible.
**At 2560x1440 every measured distance is 1.33x larger and every threshold is effectively
25% too tight.** Fixed by adding `SW()`/`SH()` length converters and applying them at all
twelve call sites.

### The limitation that cannot be engineered away

**Roblox's interface does not scale purely proportionally with the window.** Tested rather
than assumed: the game was resized to a 1280x720 client (a clean 16:9, scale 0.667) and the
loop was run.

- The hotbar check *passed* — so the coarse "can I see the UI" test is not sufficient.
- But the **progress-bar box picked up 104 near-white pixels while idle**, where at 1080p
  it reads zero. The hotbar grows relatively taller at lower resolutions and bleeds into
  the region above it.
- Result: the script believed a fish was permanently hooked and **cast zero times in 150
  seconds**.

So positions scale, but the *interface layout itself* changes. There is no coordinate
transform that fixes this — it needs recalibration.

## What was built

1. **`doctor [seconds]` mode** — read-only, sends no input. Checks AutoHotkey version,
   Windows display scaling, the Roblox window, borderless-vs-windowed, aspect ratio and
   scale factor, a stale settings file, and every detector. With a seconds argument it
   watches while the user fishes by hand so the reel-only detectors get exercised too.
   Each failure carries a concrete remedy, and it prints the detector boxes for editing.

2. **A contradiction check, which is the part that actually earns its place.** The hotbar is
   hidden while reeling, so "hotbar visible AND progress bar visible" is a state the game
   cannot be in. When both fire, a box is landing on the wrong element.

   This exists because **the first version of doctor passed the broken 720p setup as
   "all clear"** — every individual check succeeded while the loop was completely
   non-functional. Verified after the fix: at 720p doctor now reports
   `[PROBLEM] contradiction: the hotbar AND the reel progress bar are both visible`.

3. **Detector boxes are overridable from the INI** (`[boxes]` section, reference
   coordinates), so another resolution can be recalibrated without editing the script.

4. **README section**: what to copy (not the `.ini`), what the new PC needs, the resolution
   limitation stated plainly, and how to recalibrate with Ctrl+Shift+C.

## Honest answer to the question asked

**At 1920x1080 borderless fullscreen: yes, it should work — run `doctor` to confirm.**
At any other resolution: doctor will catch it, and the boxes need recalibrating. What
cannot be checked from here is Roblox's own UI-scale setting and graphics quality on the
other machine; the hotbar check is the best available proxy for the former.

No regression at 1920x1080 after all changes: 9 casts, 6 hooks, 255 shakes in 149 s, and
doctor reports ALL CLEAR.

## Answer

Resolved 2026-09-03. See above.

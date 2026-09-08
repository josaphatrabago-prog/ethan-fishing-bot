# Fisch Auto-Fisher

An AutoHotkey v2 script that plays the cast → shake → reel loop in the Roblox game **Fisch**,
with a control window for starting, watching and tuning it.

Built and tuned on 2026-09-03. **It works** — across the test runs the character went from
**Level 3 to Level 5**, and Fisch only grants experience for fish actually landed. During
reeling the fish stays inside the target zone **88% of the time**.

## Before you start

Four things the script cannot do for you:

1. **Put Roblox in borderless fullscreen — press `F11`.** This gives a game area of exactly
   1920×1080 with no title bar, which is what everything is calibrated against. In plain
   windowed mode the game area is 1920×1017 and slightly the wrong shape, and the positions
   drift.
2. **Equip your rod** in hotbar slot 1.
3. **Turn the UI toggle on — press `\`.** With Roblox's UI hidden, the cast meter, the SHAKE
   prompt and the reel bar are simply not drawn, so there is nothing on screen to read and the
   script sits at *waiting to cast* forever. This is worth checking first whenever it looks
   dead for no reason: it has already happened once, and it looks exactly like a broken
   detector.
4. **Leave Roblox in front while it runs.** Clicks only reach whichever window is at the
   front, and anything covering Roblox gets read instead of the game. The script notices and
   pauses itself rather than flailing, but it can't fish while you're in another window. In
   practice: start it and leave the machine alone.

## Running it

Double-click `fisch-autofisher.ahk`, then:

| Key | Does |
| --- | --- |
| `F9` | Start / stop |
| `F12` | Panic exit — always releases the mouse button |
| `Ctrl+Shift+C` | Capture the position and colour under your cursor (for recalibration) |

The **Test detectors** button tells you what the script currently thinks it can see, which
is the fastest way to check calibration without starting the loop.

## The two extra modes

Both run without opening the window, and both are how the script was tested:

```
AutoHotkey64.exe fisch-autofisher.ahk selftest
```

Reads every detector once, **sends no input at all**, and writes `selftest-report.txt`. Safe
to run any time. Use this first if something seems wrong.

```
AutoHotkey64.exe fisch-autofisher.ahk runfor 240
```

Runs the real loop for 240 seconds, then stops, releases the mouse and writes
`runfor-report.txt` with the counters and full log. Use this to test a change without
committing to an open-ended run.

## What it will and won't do

**Will:** cast, answer every SHAKE prompt (by pressing Enter), reel, repeat. Notice when a cast silently fails
and retry. Pause itself if Roblox isn't in front.

**Won't:** touch your inventory, sell anything, or walk anywhere. The entire input
vocabulary is left-click, `Enter` (to answer SHAKE) and `1` (to re-equip the rod if a cast
fails). Nothing else is ever sent. It also never tries for a
perfect cast — that only extends your line's reach, which is worth nothing when fishing from
one spot.

## How the reeling works

The reel minigame is the fiddly part, so it gets a proper controller rather than
simple chasing. Holding the left button drives the bar right; releasing lets it fall left.

**The one reading everything rests on: is there white right next to the fish?**

The script finds the **fish** first — that detects at 100% — and then looks for white in a
small box around it. The game paints the bar white *exactly* while the fish is inside it, so
this reads the game's own scoring state rather than working it out from geometry. Measured on
276 real frames from a recorded fight, plus ~30,000 sampled positions across them: **no false
positives and no false negatives**, at every box size from 8 to 30px. It still works when the
fish marker covers the middle of the box, because the bar's white shows at the edges.

This replaced an earlier approach that tried to locate the bar and compare positions. That
worked at the dock (96–98%) and fell to about 50% on open sea, which is what the mis-detection
looked like on screen.

The catch is that it is a **yes/no** answer. It says whether the fish is inside the bar, never
which way to move when it isn't. So the bar search is still there, but demoted to a *direction
hint* that is only believed when it agrees with the white test:

| Situation | What it does |
| --- | --- |
| Inside the bar | Trust the bar reading — the white test just confirmed it — and nudge toward centring the fish, which buys the most margin. |
| Outside, bar reading agrees | Steer straight at the fish, no dead zone. |
| Outside, readings disagree | Ignore the bar. Commit to one direction for 250ms, then reverse. |
| Outside for over 1.2s with nothing to show | Stop believing the bar even though it agrees, and sweep instead. |

That last row matters: agreement is strong evidence when the fish is *inside* the bar, and weak
when it's outside, because a bar mistakenly found on scenery is usually far from the fish too,
so it agrees by coincidence. Without the deadline the script would push at a phantom bar for
the whole fight.

It also estimates the fish's speed and aims where the fish is *going* (it can dart at
~480 px/s), and damps against the bar's own momentum so it reverses early instead of
overshooting.

Three sliders control it: **Wait for bite**, **Steering dead zone** and **Reel speed**. The
dead zone is deliberately wide (70px) — the fish only has to be *inside* the bar, whose
half-width is about 116px, so demanding tighter precision just makes it chatter.

> The detection change above is validated against recorded frames but has **not yet been
> measured live**. To judge it on data rather than impressions, run
> `AutoHotkey64.exe fisch-autofisher.ahk reeltrace 180` — it writes `reeltrace.csv` with an
> `onTgt` and a `trust` column per tick, so you can see which of the four rows above is
> actually running.

## Pinion's Aria (the falling-note rod)

This rod redraws the whole reel bar and adds a second game on top of the first, so it gets
its own set of readings. The script recognises it by itself at the start of every fight —
the log says `rod identified: Pinion's Aria` — and nothing changes for any other rod.

**What is different about the bar.** The track is *pale* lavender instead of near-black, the
bar (zone) is lit pale blue while the fish is inside it and dim mauve or red while it isn't,
and the fish marker is a thin column fading cyan to purple. So the script tells the zone from
the track by the blue channel (every tick it takes the *median* blue of the whole scan row —
the zone never covers more than about 40% of it, so that is always the track's colour — and
treats anything far from that as zone), finds the fish by the cyan top of its marker, and
reads "fish inside" from the lit blue next to the marker — the same idea as the white test
above, in this rod's colours. The bar also changes *width* mid-fight as notes are caught or
missed, which the per-tick width measurement already copes with.

The whole bar **fades in** when a fight starts. Half-faded, its colours look enough like the
default rod's fish marker that the script could lock onto the wrong rod for that fight and
then mistake the pale track for the moving bar — so the rod check is repeated every tick
until Pinion's Aria is recognised, and the `selftest` report now prints the rod mode it
settled on.

**Catching the notes.** Musical notes fall from the top of the screen and count as caught when
the bar is under them as they reach it. Catching one widens the bar and speeds progress up;
missing one shrinks the bar and speeds the fish up; seven in a row lock the fish to the bar.
The script watches the column above the bar for the *lowest* note — by shape as much as
colour, since notes fade in as they enter the screen and a single note is a much smaller
target than a double one — times how fast the first one falls, and works out when it will
land. It commits the bar to a note only when there is
just enough time to get there (`ariaNoteLeadMs` of slack on top of the travel time), and
aims for the spot nearest the fish that still has the note comfortably inside the bar
(`ariaNoteMarginPx`) — so it keeps the fish whenever both fit, and takes the note when they
don't. Each fight ends with a line like `notes: 7 of 7 landed under the bar`.

Set `ariaNotes=0` in the ini to turn the note steering off and just fish with this rod. The
other `aria*` keys are the colour windows and timing margins; the comments next to them in
the script give the measured numbers they came from. This mode needs `useCapture=1`
(the default).

> Everything about this rod was measured from six screenshots (`screenshots/aria*.png`) and
> has **not yet been run against the game**. The first things to check live are in
> `.scratch/fisch-autofisher/issues/22-pinion-aria-notes.md`; `reeltrace` now records three
> extra columns (`noteX`, `noteEta`, `noteAim`) for exactly that.

## Seeing what it's looking at

Tick **"Show detection overlay"** in the window (on by default) and the game gets annotated:

- **Red outlines** — the regions the script searches. Five boxes plus a thin line showing
  the single row it scans to find the reel zone's edges.
- **Blue squares** — where a detector actually matched something.

This is the fastest way to tell *why* something isn't working. If a red box is in the wrong
place after a Fisch update or on a new PC, you can see it immediately rather than inferring
it from odd behaviour. The markers keep updating while the loop is stopped, so you can check
calibration before pressing Start.

**The overlay is invisible to the script's own screen reads.** Each overlay window is marked
with `WDA_EXCLUDEFROMCAPTURE`, so `PixelSearch` looks straight through it — otherwise the
script would detect its own red boxes. This was verified before being relied on, and again
afterwards: a 150-second run with the overlay on produced 10 casts and 6 hooks, matching the
9 casts and 6 hooks without it.

One consequence worth knowing: **screenshots won't show the overlay either**, for the same
reason. If you want to capture it, set `overlayHideFromCapture=0` in the `[tuning]` section
of the ini — but turn it back on afterwards, because with it off the script *will* see its
own boxes and detection breaks.

## Your tuning and the settings file

Whatever you change with the sliders is saved to `fisch-autofisher.ini` next to the script, and
comes back next time. Two things worth knowing:

- **Your tuning survives script updates.** The file records not just each value but the default
  it was saved against. So when a shipped default changes, anything you deliberately tuned is
  kept, and anything you never touched quietly moves to the better default. The log says which
  did what at startup — `kept your tuning: …` / `updated to new defaults: …`.
- **A file written before this feature existed has its tuning dropped**, with a line in the log
  saying so. It has to be: without the recorded defaults there is no way to tell your value from
  a stale one. This is not hypothetical — a leftover `reelDampMs=150` from an abandoned
  experiment sat in the file overriding a default of 40, re-saved itself, and invalidated a
  measurement before anyone noticed.

**Reset to defaults** (next to *Test detectors*) puts everything back and saves.

## Known rough edges

- **The catch counter reads 0.** Detecting the "You caught a…" caption is switched off,
  because the test for it also fired on the Windows task switcher. The `hooked` count is
  real; `caught` isn't. Turning the checkbox on is a gamble until it's verified.
- **The sliders are reasoned, not optimised.** The steering values come from measurement,
  but none has been swept for a best setting, and catches per hour is still unmeasured.
- **Your saved settings beat new defaults.** If a default is improved in the script later, a
  `fisch-autofisher.ini` from before will silently keep the old value. Delete the `.ini` to
  get the shipped defaults back.
- **Recalibrating is manual.** `Ctrl+Shift+C` reports a position and colour, but you have to
  put the numbers into the script or the `.ini` yourself.

## Moving it to another PC

**Run the doctor first. It will tell you what, if anything, is wrong:**

```
AutoHotkey64.exe fisch-autofisher.ahk doctor
```

It reads only — it never sends a click or a keystroke — and writes
`doctor-report.txt`. To exercise the reeling detectors too, run `doctor 60` and fish by
hand for a minute while it watches.

### What to copy

Copy **`fisch-autofisher.ahk`** and this README. **Do not copy `fisch-autofisher.ini`.**
That file overrides the built-in defaults, and settings tuned on one machine can quietly
be wrong on another. Let the new machine write a fresh one.

### What the new PC needs

1. **AutoHotkey v2** installed (v1 will not run this — the script refuses to start on it).
2. **Roblox in borderless fullscreen** (`F11`).
3. **A 1920×1080 game area.** This matters more than it sounds — see below.
4. Windows display scaling at **100%** ideally. Doctor warns if it isn't.

### The one real limitation: resolution

Positions are stored as fractions of the game window, so they scale. **But Roblox's own
interface does not scale purely proportionally.** This was tested rather than assumed:
at 1280×720 the hotbar grows relatively taller and bleeds up into the region the script
watches for the reel progress bar, which makes it believe a fish is permanently hooked.
It then never casts at all.

So:

- **New PC also at 1920×1080** → it should work as-is. Doctor will confirm.
- **New PC at a different resolution** → doctor reports a **contradiction** (the hotbar and
  the reel progress bar cannot both be visible, since the game hides the hotbar while
  reeling). That check exists specifically because an earlier version of the doctor passed
  a broken 720p setup as "all clear".

### Recalibrating for a different resolution

Every detector box can be overridden without touching the script. Doctor prints the current
ones, and they live in the `[boxes]` section of `fisch-autofisher.ini` as reference
1920×1080 coordinates, `x1,y1,x2,y2`:

```ini
[boxes]
progress=700,970,1240,995
hotbar=700,1000,1240,1078
ring=150,150,1580,950
track=560,900,1360,945
caption=700,840,1250,885
trackInX0=578
trackInX1=1342
zoneScanY=920
```

To fix a box: hover the game and press **Ctrl+Shift+C**. The window reports the position
in *both* screen coordinates and reference coordinates — use the reference pair. Capture
the top-left and bottom-right of the element you want bounded, then write those four
numbers into the matching line and restart the script.

The two that matter most are `progress` (which decides "a fish is on") and `hotbar`
(which decides "casting or reeling"). Get those right and the loop works; the rest only
affect steering quality.

### What doctor cannot check

- **Roblox's own UI scale setting.** If it differs from the machine this was calibrated on,
  every position shifts. The hotbar check is the best available proxy.
- **Roblox graphics quality**, which changes lighting. The detectors compare bright
  interface against dark interface rather than matching exact colours, so this is usually
  survivable — but it is not guaranteed.

## If it stops working after a Fisch update

Run `selftest` first — it prints every detector's reading. The script watches for bright
interface elements inside small fixed boxes, so if Fisch moves the progress bar, the hotbar,
or the SHAKE ring, the matching detector goes quiet. The boxes are the `BOX_*` constants at
the top of the script, in 1920×1080 coordinates; `Ctrl+Shift+C` gives you replacement numbers
in the same coordinate space.

## Where the reasoning lives

`.scratch/fisch-autofisher/map.md` is the full plan and decision record: 16 tickets, what was
decided and why, what was tried and failed, and every measurement behind the numbers in the
script. Two files are worth reading over the others:

- `issues/04-status-pixel-signatures.md` — the measured detector data, with a prominent
  correction where an earlier round of analysis turned out to be wrong.
- `issues/16-reel-steering-rework.md` — how the reeling controller was measured and built,
  including the two `PixelSearch` traps that made the first two attempts fail silently.

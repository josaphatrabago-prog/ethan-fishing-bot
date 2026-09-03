# Visual overlay: show where we look and what we found

Type: prototype
Status: resolved
Blocked by: 11
Parent: ../map.md
Label: `wayfinder:prototype`

Raised by the user: *"can you add a red outline where we are detecting and a blue square on
where we detected what we were looking for"*

## Question

Can the detectors be made visible on screen without the script detecting its own overlay?

## The problem that had to be solved first

An overlay drawn over the game is, to `PixelSearch`, just more screen. Draw a red box around
the search region and the script finds red. Draw a blue marker on a hit and the next tick
finds blue. The overlay would corrupt exactly what it is meant to illustrate.

Three options were considered: draw outlines only *outside* every search box (cramped and
fragile), hide the overlay before each read (flickery and slow), or make the windows
invisible to screen capture.

**`SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE)` does the last one**, and it was
tested before anything was built on it:

| State | `PixelGetColor` under the overlay | `PixelSearch` for the overlay colour |
| --- | --- | --- |
| plain window | `0xFF00FF` (the overlay) | FOUND |
| `WDA_EXCLUDEFROMCAPTURE` set | `0x070A2A` (the game behind it) | **not found** |

Works on Windows 10 19045. The window renders normally to the eye and is simply absent from
screen capture.

## What was built

- **Red outlines** for all five detector regions (progress bar, hotbar, SHAKE ring, reel
  track, catch caption), each drawn from four thin click-through windows, plus a line
  marking the single row the zone bracketing scans.
- **Blue 12x12 markers** at the last position each detector matched.
- Refreshed on its own 120 ms timer, so it never slows the control loop. Detector results
  are recorded by `NoteHit()` as a side effect of the normal detection calls.
- **The overlay keeps updating while the loop is stopped** — the detectors are re-run
  (throttled) from the overlay timer, so calibration can be checked before pressing Start.
  Without this the boxes drew but never showed a single hit, which made the feature useless
  in exactly the situation it is most wanted.
- Drawn only while Roblox is the foreground window, so the boxes never float over other
  applications.
- A checkbox in the control window, on by default.

## The bug worth remembering

The first version rendered **nothing at all**. Cause: the overlay windows were created with
`+E0x80000` (`WS_EX_LAYERED`) alongside `+E0x20` (`WS_EX_TRANSPARENT`, which is what gives
click-through). **A layered window whose transparency is never initialised draws nothing.**

Measured directly by creating the same window five ways and counting rendered pixels:

| Style | Pixels drawn |
| --- | --- |
| `+E0x20 +E0x80000 +Disabled` | **0** |
| `+E0x20 +Disabled` | 7200 |
| `+E0x20` | 7200 |
| plain | 7256 |
| layered + `WinSetTransparent(254)` | 7209 |

The fix was to drop the layered style. `WS_EX_TRANSPARENT` alone gives click-through.

## Verification

- Screenshot with capture-hiding temporarily disabled: all five boxes and the scan line are
  in the right places, and a blue marker sits on the "Press (G) To Open" text — which is the
  exact white pixel the hotbar detector matched (measured at x 903..914, y 996..1007, a clean
  12x12 square).
- **No regression with the overlay on**: 150 s run gave 10 casts and 6 hooks, against 9 casts
  and 6 hooks with it off.

## Known consequence

Screenshots of the game will not show the overlay either, since capture is exactly what is
being excluded. `overlayHideFromCapture=0` in the ini turns that off for capturing a picture
— but with it off the script *will* detect its own boxes, so it must be turned back on.

## Answer

Resolved 2026-09-03. See above.

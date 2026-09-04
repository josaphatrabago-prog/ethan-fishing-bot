#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, Off

; =============================================================================
;  Fisch Auto-Fisher  —  AutoHotkey v2
; =============================================================================
;  Runs the cast -> shake -> reel loop for the Roblox game "Fisch".
;
;  PREREQUISITES (the script cannot set these itself):
;    1. Roblox in BORDERLESS FULLSCREEN (press F11). Gives a 1920x1080 client
;       at (0,0) with no title bar, which is what the calibration assumes.
;    2. A fishing rod equipped (hotbar slot 1).
;    3. Roblox must be the FOREGROUND window while running. Input only lands in
;       the active window, and a window covering Roblox would be read instead of
;       it. The script refuses to act when Roblox is not in front.
;
;  HOTKEYS:  F9 = start/stop      F12 = panic exit (always releases the mouse)
;
;  Every detector below was measured against live gameplay, not against
;  screenshots — see .scratch/fisch-autofisher/issues/04-status-pixel-signatures.md
;  ("LIVE-VERIFIED SIGNATURE SET"). Detectors derived from the reference
;  screenshots collapsed live; these are the replacements, and each one asks
;  "is a bright UI element rendered inside this small fixed box?" rather than
;  matching an absolute colour at a point where scenery can appear.
; =============================================================================

; ---------------------------------------------------------------- constants

; Reference resolution every coordinate below is expressed in. Scaled at runtime
; to Roblox's actual client area, so a different resolution mostly just works.
REF_W := 1920
REF_H := 1080

; Detector boxes, in reference coordinates: {x1, y1, x2, y2}.
;
; IMPORTANT for a different machine: these are calibrated against a 1920x1080
; game area. Positions scale with the window, but Roblox's own interface does
; NOT scale purely proportionally - measured at 1280x720, the hotbar grows
; relatively taller and bleeds into the progress-bar box, which makes the script
; believe a fish is permanently hooked. Every box below can be overridden from
; the [boxes] section of fisch-autofisher.ini without touching this file.
; The reel progress FILL is anchored at x=750 and grows rightward, so reading
; just its origin is enough to know a fight is on - and it is the only way to
; avoid the hotbar. The old box asked "any white pixel in 540x25", which on an
; account with a 9-slot hotbar and rod-description text put "Press (G) To Open"
; (x 895..1025) inside it: 452 white pixels while standing idle, so the bot
; believed a fish was permanently hooked and never cast. Measured across 7
; frames, this box reads 283 px while reeling and exactly 0 in every other state.
BOX_PROGRESS := [744,  970,  784,  995]   ; reel progress fill origin -> fish_on
BOX_HOTBAR   := [700, 1000, 1240, 1078]   ; item hotbar         -> hidden while casting/reeling
BOX_RING     := [150,  150, 1580,  950]   ; SHAKE ring roams; right edge avoids the leaderboard
BOX_TRACK    := [560,  900, 1360,  945]   ; reel bar, INCLUDING its end caps
; The zone search must stay inside the end-cap triangles at ~557 and ~1363:
; they are light-coloured, so a search starting at 560 locks onto the left cap
; and reports a bogus 67 px "zone" pinned to the left of the track. Measured
; from a steering trace where the zone never appeared to move at all.
TRACK_IN_X0  := 578
TRACK_IN_X1  := 1342
ZONE_W_MIN   := 150      ; 30% of the track is ~233 px; allow slack
ZONE_W_MAX   := 620      ; 70% cap is ~545 px; allow slack
; Bracketing the zone requires scanning a SINGLE horizontal line. PixelSearch
; sweeps a rectangle row by row, so over a 45 px band the "first dark pixel to
; the right" can come from any row - including inside the zone - and the right
; edge is never found. Measured: zone detection went to 0% with a band, and the
; bogus 67 px widths before that came from the same defect.
; y 920 chosen by sweeping every candidate row against 314 captured frames:
; it gives 96% detection with a median measured width of 232 px against an
; expected 231. y 908 and y 940 are the track's BORDER rows - scanning those
; returns "not dark" right across the bar and yields a nonsense 602 px zone.
ZONE_SCAN_Y  := 920
; The catch caption is CENTRED text, so it always covers the middle of the strip.
; Reading only the middle is what keeps scenery out: the new rod throws a pink
; sparkle (#FDE3FE, ref x 1115..1139) that put 141 white pixels in the old wide
; box during a fight - which would have booked every lost fish as a catch and
; pinned the reported rate at 100% regardless of what the bot actually did.
; Measured over 8 frames: 221 px on a real catch, 0 on everything else.
BOX_CAPTION  := [915,  840, 1035,  885]   ; centre of the catch caption -> success

; Colours are v2 RGB. NEVER paste a colour from an AHK v1 example: v1 was BGR,
; so red and blue are swapped and the match silently never fires.
COL_WHITE := 0xFFFFFF   ; UI chrome. var 40 => every channel >= 215.
COL_RING  := 0x6CBEFF   ; SHAKE ring. Measured 0x66B9FF..0x78D7FF live.
; The fish indicator is a ~10 px NEUTRAL BLUE-GREY vertical bar. Measured live
; across 309 of 314 reeling frames: mean #484F60, and reliably B > G > R, which
; is what separates it from the warm zone (R > B) and the near-black track.
; Two targets because a washed-out daylight scene lightens it considerably.
COL_FISH      := 0x484F60   ; normal lighting
COL_FISH_LIT  := 0xA8AEBC   ; bright/daylight scenes
; The track interior stays near-black even in full daylight - verified on 314
; frames - so "dark" is a dependable way to find where the zone is NOT.
; MEASURED value, not guessed: median RGB (34, 18, 29) across 314 reeling frames.
COL_TRACK     := 0x22121D
; "Not the track" expressed as a PixelSearch: hunting white with variation 225
; matches any pixel whose every channel is >= 30. Measured separations on the
; scan row: track min-channel 4..8, fish bar ~37, warm zone ~44, white zone 215+.
; So this catches the zone in both states and rejects the track.
NOT_TRACK_VAR := 216

; Minimum matching pixels before a detector is believed. Guards against the
; single-pixel noise seen at state transitions.
MIN_PROGRESS_PX := 0     ; PixelSearch is boolean; kept for documentation
MIN_CAPTION_PX  := 0

APP_TITLE := "Fisch Auto-Fisher"
INI_FILE  := A_ScriptDir . "\fisch-autofisher.ini"
; Bump this whenever a tuning default changes MEANING, not just its value. A
; saved INI from an older version has its [tuning] section ignored and the
; built-in defaults kept instead.
;
; This exists because of a real and quietly expensive bug: a leftover
; reelDampMs=150 from an abandoned click-rate experiment sat in the INI,
; overrode a retuned default of 40, and then re-saved itself - so a measurement
; that had already been reported was invalid, and nothing said so.
SETTINGS_VERSION := 11

; ---------------------------------------------------------------- state

; A single Map holds every GUI control. This deliberately avoids declaring one
; global per control — the POE2 notes record three sessions lost to a control
; that was assigned inside a builder function but missing from its `global`
; list, which renders fine and then throws from somewhere unrelated.
global UI := Map()
global Gui1 := ""

global Cfg := Map(
    "castHoldMs",     1000,   ; how long to hold LMB to cast
    "jitterMs",         80,   ; +/- randomisation on every wait
    "tickMs",          120,   ; outer state-poll interval
    "reelTickMs",       10,   ; inner steering interval while reeling
    "tolWhite",         40,   ; PixelSearch variation for UI white
    "tolRing",          40,   ; PixelSearch variation for the SHAKE ring
    ; Tightened from 34: at 24 the first match inside the scan band already
    ; satisfies B > G > R on both reference frames, so the ordering check almost
    ; never has to reject a candidate and search again.
    "tolFish",          24,   ; fish bar: measured spread needs ~34, not 18
    "tolTrack",         34,   ; legacy: track-colour match (no longer used to close runs)
    ; The boundary between the track and anything drawn on it. Raised from 29:
    ; a second fishing location renders the track at #20221D, min channel 29,
    ; sitting exactly ON the old boundary - so single pixels flickered across it
    ; and the bar's left edge latched onto noise 61 px early. Measured window:
    ; 33..44 works for every reference frame. Below 33 the new location's track
    ; reads as bar; above 44 the old rod's off-target bar (min 47) reads as track.
    ; 38 sits centrally, ~9 either side.
    "darkMax",          38,   ; a pixel is "dark" when EVERY channel is <= this
    ; Steering, all derived from measured rates: the zone travels +198 px/s held
    ; and -207 px/s released, while the fish moves 30 px/s typically and up to
    ; 484 px/s when it darts.
    "reelLeadMs",       70,   ; predict the fish this far ahead (covers a dart)
    ; The fish only has to be INSIDE the zone, whose half-width is ~116 px - not
    ; centred in it. A 14 px dead zone demanded precision the game never asks
    ; for and guaranteed chatter; 70 px keeps good margin with far less thrash.
    ; One tick of bar travel. There is no neutral - the bar moves at ~385 px/s
    ; whether held or released - so a wide dead band is not "hold position", it is
    ; uncorrected drift. 70 px left on-target offsets at a median 57 px from
    ; centre, with under 60 px of margin before the fish slipped out.
    "reelDeadPx",       25,
    ; The bar's WIDTH is a rod stat and constant within a session - measured
    ; 232 px at 1920x1080, range 227..233 across 280 frames. Only the LEFT EDGE
    ; needs finding; the centre follows. Update this if the rod changes.
    "zoneWidth",       232,
    ; The coloured-bar rod's bar is much wider. Selected by which marker is in
    ; use, because there is no cheap way to measure the right edge every tick.
    "zoneWidthPale",   411,
    ; "bright" rather than "white": PixelSearch on 0xFFFFFF with this variation
    ; matches any pixel whose channels are all >= 255 - tol. At 135 that is
    ; >= 120, which catches a coloured progress bar as well as a white one, and
    ; still reads 0 on every non-reeling reference frame.
    "tolProgress",     135,
    ; The on-target test: look for the bar's white in a box this many pixels
    ; around the fish. Anything from 8 to 30 px scored perfectly offline; 14 is
    ; mid-range - wide enough to see past the fish glyph, narrow enough that
    ; "inside" still means inside.
    "onTargetRx",       14,
    "onTargetRy",        6,
    ; How long to commit to a guessed direction when the bar cannot be located.
    "probeMs",         250,
    ; How long a dropped fish reading stays usable. The reading is missing on 28%
    ; of ticks in bursts of 1-4; at a median 64 px/s the fish moves ~17 px in that
    ; time, so its last position is a far better aim point than the mid-track
    ; default the loop used to fall back on.
    "fishMemoryMs",    400,
    ; How long to keep steering at a located bar with nothing to show for it
    ; before deciding the reading is scenery and sweeping instead.
    "distrustMs",     1200,
    ; Damping. The zone ACCELERATES rather than moving at a fixed speed
    ; (measured spread +/-400 px/s), so pure bang-bang overshoots and oscillates
    ; across the whole track. Steering on (error - Kd * zoneVelocity) reverses
    ; early, which is what stops the swinging.
    ; Look ahead far enough to cancel the bar's momentum. Measured: after the
    ; command reverses, the bar still travels a median 144 px - more than its own
    ; 116 px half-width - so a late reversal ejects the fish by itself. At a
    ; median 321 px/s that overshoot takes ~450 ms to play out, and 89% of
    ; on-target stretches were ended by the bar moving, not the fish.
    "reelDampMs",      450,
    "ringOffsetY",      60,   ; ring hit is near its top edge; add this to reach the centre
    "shakeGapMs",      220,   ; minimum gap between shake presses
    ; 1 = press Enter, 2 = click the ring, 3 = both.
    ; Enter is the default on the user's advice: it answers SHAKE directly, and
    ; unlike clicking it needs no ring-centre estimate and never moves the
    ; cursor away from where the reel loop wants it.
    "shakeMethod",       1,
    "postCastMs",      600,   ; settle time after releasing a cast
    ; How long to wait for a bite before assuming the cast failed and re-casting.
    ; This exists because a purely stateless `idle` fall-through re-casts
    ; immediately and cancels its own cast — measured: 89 casts, 0 bites in 149s.
    "biteWaitMs",    12000,
    ; The first cast straight after a reel reliably fails - the game is still
    ; finishing the catch. Settle before re-casting rather than fighting it.
    "postReelMs",     2500,
    "castFailsBeforeToggle", 3,
    "castPointX",      400,   ; where to aim before clicking (reference coords).
    "castPointY",      480,   ; Must be inside the game and clear of this GUI.
    "useJitter",         1,
    ; Count catches from the "You just caught a ..." caption. ON now that it is
    ; measured: 1160 white pixels in the caption box on a catch, 0 on all five
    ; non-catch reference frames. Without this there is no catch rate at all.
    "detectSuccess",     1,
    ; How long after a reel ends to keep looking for the caption before calling
    ; the fish lost. The caption does not render on the same tick the reel bar
    ; disappears, which is what made every catch count as a loss.
    ; Must stay BELOW postReelMs, or DoCast preempts the tail of the window and
    ; blocks ~1.7 s with the button held while a caption goes unread.
    "resolveMs",      2200,
    ; Refuse to start unless the Roblox client area matches the resolution the
    ; boxes were calibrated against. Set to 0 only after genuinely recalibrating
    ; the boxes for a different size - see "Recalibrating" in the README.
    ; Without this, a windowed client silently shifts every box onto the wrong UI
    ; and the bot sits in a fake reel forever instead of fishing.
    "requireExactRes",   1,
    ; Debug overlay: red outlines show WHERE the script looks, blue squares show
    ; WHAT it found. On by default so it is discoverable; untick it in the
    ; window for a clean screen during a long unattended run.
    "overlay",           1,
    ; Hide the overlay from screen capture so the script cannot detect its own
    ; boxes. Verified working here (Windows 10 19045). Turn OFF only to
    ; screenshot the overlay - with it off, the script WILL see the overlay and
    ; detection breaks.
    "overlayHideFromCapture", 1,
    "overlayThickness",  2
)

; The values as SHIPPED, captured before any settings file is applied. Saved
; alongside the user's values so a later run can tell "they tuned this" from
; "this is just what the default was back then".
global Defaults := Cfg.Clone()

global Running   := false
global Status    := "idle"
global PrevStatus := ""
; `unresolved` is the honest third outcome: a fish that was hooked but whose
; result could not be observed - focus left Roblox during the caption window, the
; bounded run ended mid-fight, or the loop was stopped. Counting those as losses
; understates the catch rate for reasons that have nothing to do with fishing, so
; they are excluded from the rates instead.
; `castsOk` counts only casts that actually entered the water.
global Counters  := Map("casts", 0, "castsOk", 0, "shakes", 0, "hooked", 0,
                        "caught", 0, "lost", 0, "unresolved", 0)
global SessionStart := 0
global MouseIsDown  := false
global LastZoneX    := 0
global LastFishX    := 0
global LastFishSeen := 0   ; most recent fish x, for the zone search
; Which marker rendering this fight is using. 0 = not yet known, 1 = blue-grey
; (white bar), 2 = pale grey (coloured bar). Latched to 1 the first time the
; blue-grey rule succeeds, so the pale pass can never match a white bar.
global MarkerMode   := 0
global SettingsKept  := []     ; keys the user tuned, kept across a version bump
global SettingsMoved := []     ; keys reset because only the shipped default changed
global SettingsReset := false  ; true when provenance was unknown and tuning was dropped
global ProbeDir     := 0   ; which way a blind probe is currently pushing
global ProbeUntil   := 0   ; when the current probe window expires
global OffSince     := 0   ; when the fish last went off-target, 0 while on it
global ResolveUntil := 0   ; deadline for deciding whether a finished reel landed
global ResolvePend  := false   ; a finished reel is waiting to be judged
; True from the moment a cast is made until the fish it produced is judged.
; Nothing can be hooked while it is false, which is what stops the post-catch UI
; from being read as a fresh fight over and over.
global LineOut      := false
; Reel diagnostics, accumulated across a run so a bounded run can report them.
global ReelTicks    := 0   ; control decisions taken while reeling
global ReelOnTicks  := 0   ; of those, how many had the fish inside the bar
global ReelPeriodMs := 0   ; summed loop period, for the true control rate
global ReelPeriodN  := 0
global LastFishAt   := 0
global FishVel      := 0      ; px/sec, signed
global LastZoneAt   := 0
global ZoneVel      := 0      ; px/sec, signed - the zone has real momentum
global StatusSince  := 0
global NextCastAt   := 0
global CastFailStreak := 0
; True once slot 1 has been toggled during the current failure streak. The next
; failure then flips it straight back rather than waiting out another three.
global ToggledInStreak := false
global CalibTarget  := ""
global ReelTrace    := false   ; enabled by the `reeltrace` argument
global LastOvlAt    := 0       ; throttle for in-loop overlay refreshes

; Debug overlay state. `Hits` records the last position each detector matched,
; so the overlay can be refreshed on its own slow timer instead of costing time
; inside the control loop.
global OvlBars := Map()        ; name -> Gui, the red region outlines
global OvlMarks := Map()       ; name -> Gui, the blue hit markers
global OvlBuilt := false
global Hits := Map()

; Roblox client geometry, refreshed each tick.
global CX := 0, CY := 0, CW := REF_W, CH := REF_H, RbxHwnd := 0

; ---------------------------------------------------------------- safety

; Releasing the mouse is the single most important thing this script does. A
; left button left held down outlives the process and makes the desktop
; unusable, so every exit path goes through here.
ReleaseMouse(*) {
    global MouseIsDown
    if MouseIsDown {
        try Click "up"
        MouseIsDown := false
    }
    ; Ask the OS directly as well, in case AHK's own state got out of step.
    try DllCall("mouse_event", "uint", 0x0004, "uint", 0, "uint", 0, "uint", 0, "ptr", 0)
}
OnExit(ExitHandler)

ExitHandler(reason, code) {
    ReleaseMouse()
    try OvlDestroy()
    SaveSettings()
    return 0
}

HoldMouse() {
    global MouseIsDown
    if !MouseIsDown {
        Click "down"
        MouseIsDown := true
    }
}

; ---------------------------------------------------------------- geometry

; Roblox keeps hidden SystrayIcon and IME windows alive even with no game open,
; so matching on ahk_exe alone finds a window that cannot be read. Take the
; largest VISIBLE window owned by a Roblox-named process instead.
FindRoblox() {
    best := 0, bestArea := 0
    for h in WinGetList() {
        if !DllCall("IsWindowVisible", "ptr", h)
            continue
        try {
            if !InStr(WinGetProcessName("ahk_id " . h), "Roblox")
                continue
            WinGetPos( , , &w, &hh, "ahk_id " . h)
        } catch
            continue
        if (w * hh > bestArea && w * hh >= 300000)
            best := h, bestArea := w * hh
    }
    return best
}

RefreshGeometry() {
    global CX, CY, CW, CH, RbxHwnd
    RbxHwnd := FindRoblox()
    if !RbxHwnd
        return false
    try WinGetClientPos(&CX, &CY, &CW, &CH, "ahk_id " . RbxHwnd)
    catch
        return false
    return (CW > 0 && CH > 0)
}

; Roblox must be in front: input only reaches the active window, and anything
; covering Roblox would be read in its place.
RobloxIsFront() {
    global RbxHwnd
    return RbxHwnd && (DllCall("GetForegroundWindow", "ptr") = RbxHwnd)
}

; Positions: reference coordinate -> absolute screen coordinate.
SX(x) => CX + Round(CW * x / REF_W)
SY(y) => CY + Round(CH * y / REF_H)

; LENGTHS: a distance in reference pixels -> the same distance in screen pixels.
; Everything measured off the screen (zone widths, aim errors, velocities) comes
; back in screen pixels, so any constant compared against it must be converted
; too. Without these the script only behaves correctly at exactly 1920x1080 -
; at 2560x1440 every measured distance is 1.33x larger and every threshold is
; effectively 25% too tight.
SW(n) => Round(CW * n / REF_W)
SH(n) => Round(CH * n / REF_H)

; ---------------------------------------------------------------- detection

; Wrapper so every search shares one failure policy. v2 throws OSError when the
; screen capture itself fails, which is a different thing from "colour absent".
FindIn(box, colour, tol, &fx, &fy) {
    try
        return PixelSearch(&fx, &fy, SX(box[1]), SY(box[2]), SX(box[3]), SY(box[4]),
                           colour, tol)
    catch
        return false
}

HasProgressBar() {
    global BOX_PROGRESS, COL_WHITE, Cfg
    ; BRIGHT, not white - the progress bar is white on one rod and a pink-to-
    ; purple gradient on another. Measured: 350 px and 330 px respectively, and
    ; 0 on every frame where no fight is running.
    if FindIn(BOX_PROGRESS, COL_WHITE, Cfg["tolProgress"], &x, &y) {
        NoteHit("progress", x, y)
        return true
    }
    NoteHit("progress", 0, 0)
    return false
}

HasHotbar() {
    global BOX_HOTBAR, COL_WHITE, Cfg
    if FindIn(BOX_HOTBAR, COL_WHITE, Cfg["tolWhite"], &x, &y) {
        NoteHit("hotbar", x, y)
        return true
    }
    NoteHit("hotbar", 0, 0)
    return false
}

; Returns [x, y] of the ring's approximate centre, or 0.
; PixelSearch scans top-to-bottom, so the first hit sits near the ring's top
; edge; adding ringOffsetY lands inside the button.
FindShakeRing() {
    global BOX_RING, COL_RING, Cfg
    if FindIn(BOX_RING, COL_RING, Cfg["tolRing"], &x, &y) {
        cy := y + Round(CH * Cfg["ringOffsetY"] / REF_H)
        NoteHit("ring", x, cy)
        return [x, cy]
    }
    NoteHit("ring", 0, 0)
    return 0
}

HasCaption() {
    global BOX_CAPTION, COL_WHITE, Cfg
    if FindIn(BOX_CAPTION, COL_WHITE, Cfg["tolWhite"], &x, &y) {
        NoteHit("caption", x, y)
        return true
    }
    NoteHit("caption", 0, 0)
    return false
}

; --- reel bar geometry -----------------------------------------------------
;
; The old version searched for near-white to find the zone. That was wrong twice
; over: PixelSearch returns the LEFTMOST match, so it yielded the zone's left
; EDGE and steered the fish at the edge rather than the middle; and the zone is
; only white while the fish is already inside it, so exactly when steering
; mattered most the position was unknown and a stale value got reused.
;
; This version brackets the zone instead. The zone (white when on target, warm
; brown when not) is always far brighter than the near-black track, so:
;   left edge  = first non-dark pixel scanning the track band
;   right edge = first dark pixel after that
; Both states are handled by one pair of searches, and the CENTRE falls out.
FindZone(&zoneLo, &zoneHi, &zoneCentre) {
    global COL_WHITE, Cfg, NOT_TRACK_VAR, TRACK_IN_X0, TRACK_IN_X1, MarkerMode

    zoneLo := zoneHi := zoneCentre := 0
    left := SX(TRACK_IN_X0)
    right := SX(TRACK_IN_X1)
    ; The two rod skins have very different bar widths, and the marker in use
    ; identifies which one this is.
    width := SW(MarkerMode = 2 ? Cfg["zoneWidthPale"] : Cfg["zoneWidth"])

    ; Only the LEFT EDGE is detected; the width is known, so the rest follows.
    ;
    ; The previous version bracketed both edges, closing the run at the first
    ; dark pixel. That was the weak link: PixelSearch can only ask "are ALL
    ; channels dark", whereas the run genuinely ends where ANY channel goes
    ; dark, so runs frequently overshot the bar and were rejected by the width
    ; gate. Measured live at ~50% detection. Left-edge-plus-width scored 100%
    ; on the same frames, with a median centre error of 0 px.
    fishX := LastFishSeen
    cursor := left

    loop 4 {
        if !TrackScanX(cursor, right, COL_WHITE, NOT_TRACK_VAR, &lo)
            return false

        ; The fish marker is also "not track". If the edge we found is really
        ; the fish, step past it and keep looking.
        if (fishX && Abs(lo - fishX) <= SW(16)) {
            cursor := fishX + SW(17)
            if (cursor >= right)
                return false
            continue
        }

        ; Confirm the bar is actually here: its middle must also be non-track.
        ; This rejects the few-pixel artifacts that appear near the track's
        ; left edge in some scenes.
        mid := Min(right - 1, lo + width // 2)
        if !PixelIsNotTrack(mid) {
            cursor := lo + SW(8)
            if (cursor >= right)
                return false
            continue
        }

        zoneLo := lo
        zoneHi := Min(right, lo + width)
        zoneCentre := (zoneLo + zoneHi) // 2
        y := SY(ZONE_SCAN_Y)
        NoteHit("zoneLo", zoneLo, y)
        NoteHit("zoneHi", zoneHi, y)
        NoteHit("zoneC", zoneCentre, y)
        return true
    }

    NoteHit("zoneLo", 0, 0)
    NoteHit("zoneHi", 0, 0)
    NoteHit("zoneC", 0, 0)
    return false
}

; True when the pixel on the scan row is NOT the near-black track, i.e. every
; channel is above the darkness threshold.
PixelIsNotTrack(x) {
    global ZONE_SCAN_Y, Cfg
    try {
        c := PixelGetColor(x, SY(ZONE_SCAN_Y))
    } catch {
        return false
    }
    lim := Cfg["darkMax"]
    return (((c >> 16) & 0xFF) > lim) && (((c >> 8) & 0xFF) > lim) && ((c & 0xFF) > lim)
}

; THE on-target signal, and the most reliable reading in the whole script.
;
; Rather than locating the bar and comparing positions, look for the bar's WHITE
; in a small box around the FISH. The game paints the bar white exactly while the
; fish is inside it, so this reads the game's own scoring state instead of
; inferring it from geometry - and the fish detects at 100%, so the box is always
; anchored on something real.
;
; Measured on 276 real reel frames, plus ~30k sampled positions across them:
; zero false positives and zero false negatives, at every radius from 8 to 30 px
; and every threshold tried. It is unbothered by the fish glyph covering the
; middle of the box, because the bar's white still shows at the edges.
;
; What it CANNOT do is say which way to move when the answer is "outside" - it is
; one bit. DoReel gets direction elsewhere.
FishOnTarget(fishX) {
    global ZONE_SCAN_Y, COL_WHITE, Cfg
    if !fishX {
        NoteHit("onTgt", 0, 0)
        return false
    }
    rx := SW(Cfg["onTargetRx"])
    ry := SH(Cfg["onTargetRy"])
    y := SY(ZONE_SCAN_Y)
    try {
        if PixelSearch(&wx, &wy, fishX - rx, y - ry, fishX + rx, y + ry,
                       COL_WHITE, Cfg["tolWhite"]) {
            NoteHit("onTgt", wx, wy)
            return true
        }
    }
    NoteHit("onTgt", 0, 0)
    return false
}

; Horizontal search along ONE scan line. Takes and returns SCREEN x.
; Single-line is essential: a multi-row rectangle makes left-to-right
; bracketing meaningless, because a match may come from any row.
TrackScanX(screenX1, screenX2, colour, tol, &foundX) {
    global ZONE_SCAN_Y
    foundX := 0
    if (screenX2 <= screenX1)
        return false
    ; A 3 px band rather than a single row: a zero-height rectangle is a
    ; degenerate case for PixelSearch, and the zone spans far more than 3 px
    ; vertically, so this stays a "single line" in effect. (The original 45 px
    ; band was the real problem - it spanned the track's borders.)
    y := SY(ZONE_SCAN_Y)
    try {
        if PixelSearch(&fx, &fy, screenX1, y - 1, screenX2, y + 1, colour, tol) {
            foundX := fx
            return true
        }
    }
    return false
}

; Find the fish marker on the bar's own scan row.
;
; Two things make this reliable, and BOTH are load-bearing:
;
;   1. A narrow band around ZONE_SCAN_Y, between the track's inner edges. The old
;      box spanned y 900..945 starting at x 560, so PixelSearch - which scans the
;      top row first - matched scenery above the track and the light end cap,
;      never the fish. Measured error: 348 px and 334 px.
;   2. B > G > R. The marker is blue-grey; the false matches are warm brown, and
;      no colour cube separates them because their channels overlap. The band
;      alone still returned a brown pixel 321 px off on one reference frame; the
;      ordering test is what fixes it.
;
; With both: 3 px and 5 px error on the reference frames.
FindFishX() {
    global COL_FISH, COL_FISH_LIT, LastFishSeen, MarkerMode

    ; The marker has two renderings - a dark blue-grey and a lighter one. Trying
    ; the dark one first costs nothing when it hits, which is the common case.
    ;
    ; Dropping this fallback cost two fish out of ten: in both losing fights the
    ; fish was missing for 63-72% of the fight while the bar read normally, and
    ; every fight where it stayed visible was landed.
    x := ScanForMarker(COL_FISH)
    if !x
        x := ScanForMarker(COL_FISH_LIT)
    if x
        MarkerMode := 1      ; blue-grey marker: latch, and never try pale again

    ; Only if no blue-grey marker has been seen this fight. On the old rod that
    ; rule succeeds immediately, so this never runs - which is the point, because
    ; on a white bar this pass would return the BAR as the fish.
    if (!x && MarkerMode != 1) {
        x := ScanForPaleMarker()
        if x
            MarkerMode := 2
    }

    if x {
        NoteHit("fish", x, SY(ZONE_SCAN_Y))
        LastFishSeen := x
        return x
    }
    NoteHit("fish", 0, 0)
    return 0
}

; The pale marker: a narrow achromatic column on a coloured bar.
;
; Two conditions, and both are needed. Achromatic (max channel minus min <= 12)
; rejects the coloured bar it sits on. Narrow - neither side 24 px away is still
; pale - rejects any broad white area. Even so this is only ever called when no
; blue-grey marker has been seen this fight, because on a white bar no local test
; can tell the bar's own edge from a marker.
ScanForPaleMarker() {
    global Cfg, TRACK_IN_X0, TRACK_IN_X1, ZONE_SCAN_Y, COL_WHITE

    y1 := SY(ZONE_SCAN_Y - 3)
    y2 := SY(ZONE_SCAN_Y + 3)
    right := SX(TRACK_IN_X1)
    cursor := SX(TRACK_IN_X0)
    side := SW(24)

    loop 10 {
        found := false
        try found := PixelSearch(&x, &y, cursor, y1, right, y2,
                                 COL_WHITE, Cfg["tolWhite"])
        if !found
            return 0
        if (IsAchromatic(x, y) && !IsPale(x - side, y) && !IsPale(x + side, y))
            return x
        cursor := x + SW(2)
        if (cursor >= right)
            return 0
    }
    return 0
}

IsAchromatic(x, y) {
    try {
        c := PixelGetColor(x, y)
    } catch {
        return false
    }
    r := (c >> 16) & 0xFF, g := (c >> 8) & 0xFF, b := c & 0xFF
    return (Max(r, g, b) - Min(r, g, b)) <= 12
}

IsPale(x, y) {
    global Cfg
    try {
        c := PixelGetColor(x, y)
    } catch {
        return false
    }
    lim := 255 - Cfg["tolWhite"]
    return (((c >> 16) & 0xFF) >= lim) && (((c >> 8) & 0xFF) >= lim)
        && ((c & 0xFF) >= lim)
}

; One band-plus-ordering pass for a single marker colour.
;
; Two things make this reliable, and BOTH are load-bearing:
;
;   1. A narrow band around ZONE_SCAN_Y, between the track's inner edges. The old
;      box spanned y 900..945 starting at x 560, so PixelSearch - which scans the
;      top row first - matched scenery above the track and the light end cap,
;      never the fish. Measured error: 348 px and 334 px.
;   2. Blue must lead red. The false matches are warm brown, and no colour cube
;      separates them because their channels overlap. The band alone still
;      returned a brown pixel 321 px off on one reference frame.
;
; With both: 3 px and 5 px error on the reference frames.
ScanForMarker(colour) {
    global Cfg, TRACK_IN_X0, TRACK_IN_X1, ZONE_SCAN_Y

    y1 := SY(ZONE_SCAN_Y - 3)
    y2 := SY(ZONE_SCAN_Y + 3)
    right := SX(TRACK_IN_X1)
    cursor := SX(TRACK_IN_X0)

    ; Bounded: a candidate that fails the ordering test is stepped past. In
    ; practice the first candidate passes, so this costs one extra read.
    loop 6 {
        found := false
        try found := PixelSearch(&x, &y, cursor, y1, right, y2,
                                 colour, Cfg["tolFish"])
        if !found
            return 0
        if IsFishPixel(x, y)
            return x
        cursor := x + SW(2)
        if (cursor >= right)
            return 0
    }
    return 0
}

; The marker is blue-grey, so blue leads and red trails. Warm brown scenery sits
; inside the same colour cube but has it the other way round, which is why the
; cube alone cannot separate them.
IsFishPixel(x, y) {
    try {
        c := PixelGetColor(x, y)
    } catch {
        return false
    }
    r := (c >> 16) & 0xFF
    b := c & 0xFF
    ; Blue must clearly lead red. Requiring B > G > R exactly also rejected
    ; part-antialiased marker pixels, where blue and green sit within a count of
    ; each other; that showed up as 28% of reads coming back empty. Every warm
    ; brown false match measured - (106,74,68), (103,73,67), (87,73,69) - fails
    ; this just as decisively.
    return (b > r + 6)
}

; Priority order matters: the first match wins and `idle` is the fall-through.
; Ordered by how time-critical each state is, then by detector reliability.
DetectStatus() {
    global Cfg, Status, NextCastAt, LineOut
    ; A fish can only be hooked when there is a line in the water. Without this
    ; guard the post-catch UI intermittently satisfies the progress-bar test, and
    ; the state machine cascades fish_on -> idle -> bait -> fish_on about once a
    ; second, booking a phantom hooked AND a phantom caught on every pass. One run
    ; reported 26 hooks from 13 casts that way.
    if (LineOut && HasProgressBar())
        return "fish_on"
    ; The ring detector is only consulted when a bite is actually possible:
    ;   * not during a fight - one dropped read of the progress bar would
    ;     otherwise flip fish_on -> bait, booking a phantom lost AND a phantom
    ;     hooked for a fish still being fought, halving the reported catch rate;
    ;   * only while a line is in the water, i.e. inside the bite window opened
    ;     by a cast. While genuinely idle there is nothing to shake, so asking is
    ;     pure downside - and it was measured firing on scenery in 4 of 5 bite
    ;     states, each costing 4-10 s.
    ; Not looking is a stronger fix than looking harder, and it is the same
    ; approach that removed the catch caption's false positives.
    if (Status != "fish_on" && A_TickCount < NextCastAt && FindShakeRing())
        return "bait"
    if !HasHotbar()
        return "casting"
    return "idle"
}

; ---------------------------------------------------------------- helpers

Jitter(ms) {
    global Cfg
    if !Cfg["useJitter"]
        return ms
    j := Cfg["jitterMs"]
    return Max(10, ms + Random(-j, j))
}

Join(arr, sep) {
    out := ""
    for v in arr
        out .= (out = "" ? "" : sep) . v
    return out
}

LogLine(text) {
    global UI
    if !UI.Has("log")
        return
    stamp := FormatTime(, "HH:mm:ss")
    prev := UI["log"].Value
    lines := StrSplit(prev, "`n")
    if (lines.Length > 200)
        prev := ""
    UI["log"].Value := prev . (prev = "" ? "" : "`n") . stamp . "  " . text
    ; Scroll to the bottom.
    try SendMessage(0x0115, 7, 0, UI["log"].Hwnd)
}

; ---------------------------------------------------------------- actions

DoCast() {
    global Counters, Cfg, NextCastAt, CastFailStreak, LineOut, ToggledInStreak

    ; Aim first. The control window floats above fullscreen Roblox, so a click
    ; made while the cursor is over the GUI goes to the GUI and never reaches
    ; the game.
    MouseMove(SX(Cfg["castPointX"]), SY(Cfg["castPointY"]), 0)
    Sleep 60
    HoldMouse()

    ; Confirm the cast actually STARTED rather than assuming it did. The hotbar
    ; hides while casting, so its absence during the hold is proof. Without this
    ; check the loop happily "casts" 89 times with no rod equipped and reports
    ; success — which is exactly what happened before this was added.
    target := Jitter(Cfg["castHoldMs"])
    started := false
    waited := 0
    while (waited < target) {
        Sleep 100
        waited += 100
        if !HasHotbar()
            started := true
    }
    ReleaseMouse()
    Counters["casts"]++
    if started
        Counters["castsOk"]++

    if !started {
        CastFailStreak++
        LogLine("cast #" . Counters["casts"] . " did not register (hotbar stayed"
            . " visible)  [streak " . CastFailStreak . "]")
        ; Roblox hotbar number keys TOGGLE equip/unequip, so pressing "1" on the
        ; FIRST failure unequips a rod that was fine — which is what made every
        ; post-reel cast fail twice before succeeding. Only reach for it once
        ; failures persist.
        ; A hotbar key TOGGLES, so the first attempt is a coin flip on whether
        ; the rod ends up equipped. If a toggle has already been tried in this
        ; streak, one more failure is enough to say it went the wrong way - flip
        ; back at once rather than waiting out another full threshold.
        needed := ToggledInStreak ? 1 : Cfg["castFailsBeforeToggle"]
        if (CastFailStreak >= needed) {
            LogLine("  " . (ToggledInStreak ? "still failing — flipping slot 1 back"
                                            : "persistent failure — toggling slot 1"))
            Send "1"
            Sleep 700
            ToggledInStreak := true
            CastFailStreak := 0
        }
        NextCastAt := A_TickCount + 1200
        return
    }

    CastFailStreak := 0
    ToggledInStreak := false
    LineOut := true
    LogLine("cast #" . Counters["casts"] . " away — waiting up to "
        . Round(Cfg["biteWaitMs"] / 1000) . "s for a bite")
    Sleep Jitter(Cfg["postCastMs"])
    NextCastAt := A_TickCount + Cfg["biteWaitMs"]
}

; Answer a SHAKE prompt. `ring` may be 0 when the method does not need it.
;
; Enter is the default. Clicking required estimating the ring's centre from a
; PixelSearch hit near its top edge, which is an offset guess, and it dragged the
; cursor away from the game area between prompts. A keypress has neither problem.
DoShake(ring) {
    global Counters, Cfg
    ReleaseMouse()          ; never hold the button through a shake

    if (Cfg["shakeMethod"] = 2 || Cfg["shakeMethod"] = 3) {
        if ring {
            MouseMove(ring[1], ring[2], 0)
            Sleep 25
            Click
        }
    }
    if (Cfg["shakeMethod"] = 1 || Cfg["shakeMethod"] = 3)
        Send "{Enter}"

    Counters["shakes"]++
    Sleep Jitter(Cfg["shakeGapMs"])
}

; The reel minigame. The zone drifts LEFT on its own and holding the left button
; drives it RIGHT, so this is a two-state hold/release controller, not a
; positioning one. Catch progress is symmetric at roughly +/-12%/sec, so the
; loop only has to be net-positive, not perfect.
DoReel() {
    global Cfg, Counters, LastZoneX, Running, BOX_TRACK
    global LastFishX, LastFishAt, FishVel, MouseIsDown, LastFishSeen
    global MarkerMode
    global LastZoneAt, ZoneVel, LastOvlAt, ProbeDir, ProbeUntil, OffSince
    global ReelTicks, ReelOnTicks, ReelPeriodMs, ReelPeriodN
    ; Fresh reel: no stale velocity or position from the previous fish.
    LastFishX := 0, LastFishAt := 0, FishVel := 0
    LastZoneX := 0, LastZoneAt := 0, ZoneVel := 0
    ProbeDir := 0, ProbeUntil := 0, OffSince := 0
    LastFishSeen := 0   ; never inherit the previous fight's position
    MarkerMode := 0     ; re-identify the rod skin on every fight
    guard := A_TickCount
    LastTickAt := 0
    ; Tolerate dropped frames. The progress bar detector reads a variable-width
    ; FILL, so it legitimately reads empty for a moment mid-fight. Each miss costs
    ; a read plus a sleep (~24 ms), so 3 misses was only ~72 ms of tolerance - and
    ; exiting early hands the fight to MainTick, which has none at all and books a
    ; phantom lost/hooked pair. 8 misses is ~190 ms.
    misses := 0
    while (Running && misses < 8 && A_TickCount - guard < 90000) {
        if !HasProgressBar() {
            misses++
            Sleep Cfg["reelTickMs"]
            continue
        }
        misses := 0
        if !RobloxIsFront() {
            ReleaseMouse()
            LogLine("Roblox lost focus — pausing")
            return
        }
        fishX := FindFishX()
        haveZone := FindZone(&zLo, &zHi, &zC)
        if (haveZone) {
            tNow := A_TickCount
            if (LastZoneX && LastZoneAt && tNow > LastZoneAt) {
                dtz := tNow - LastZoneAt
                if (dtz < 400) {
                    vz := (zC - LastZoneX) * 1000 / dtz
                    ; Smooth it: single-frame edge jitter would otherwise swamp
                    ; the damping term.
                    ZoneVel := Round(ZoneVel * 0.5 + Max(-SW(900), Min(SW(900), vz)) * 0.5)
                }
            }
            LastZoneX := zC
            LastZoneAt := tNow
        }
        ; With a pale marker the white test would match the MARKER, so it would
        ; report "on target" forever. Fall back to geometry, which needs no
        ; assumption about what colour the game paints anything.
        onTarget := (MarkerMode = 2)
            ? (haveZone && fishX && fishX >= zLo && fishX <= zHi)
            : FishOnTarget(fishX)

        ; Dwell and true control rate. The rate is not what reelTickMs says: the
        ; loop is capture-bound, so this measures what it actually achieved.
        ReelTicks++
        if onTarget
            ReelOnTicks++
        if (LastTickAt) {
            ReelPeriodMs += A_TickCount - LastTickAt
            ReelPeriodN++
        }
        LastTickAt := A_TickCount

        now := A_TickCount
        if (fishX) {
            ; Estimate the fish's speed from the previous reading, then aim at
            ; where it is GOING rather than where it is. Measured: the fish
            ; usually drifts at ~30 px/s but can dart at up to ~484 px/s, and at
            ; a dart 70 ms of lead is worth ~34 px - the difference between
            ; tracking it and trailing it.
            if (LastFishX && LastFishAt && now > LastFishAt) {
                dt := now - LastFishAt
                jump := Abs(fishX - LastFishX)
                ; A jump beyond ~300 px between ticks is a misdetection, not a
                ; fish: the fastest dart measured was 484 px/s, i.e. ~11 px per
                ; tick. One bad reading produced a -5081 px/s spike in the trace.
                if (dt < 400 && jump < SW(300)) {
                    v := (fishX - LastFishX) * 1000 / dt
                    FishVel := Max(-SW(600), Min(SW(600), v))
                }
            }
            LastFishX := fishX
            LastFishAt := now
        }

        ; Carry the fish across short gaps in the reading, extrapolated by its
        ; last known speed. Note `onTarget` is deliberately NOT derived from this
        ; - the white test needs a real, current position to read around, and a
        ; remembered one would fabricate an on-target signal.
        aimX := fishX
        if (!aimX && LastFishX && LastFishAt
            && (now - LastFishAt) < Cfg["fishMemoryMs"]) {
            aimX := LastFishX + Round(FishVel * (now - LastFishAt) / 1000)
            aimX := Max(SX(TRACK_IN_X0), Min(SX(TRACK_IN_X1), aimX))
        }

        halfW := SW(Cfg["zoneWidth"]) // 2
        ; The bar's position is only trusted when it AGREES with the white test.
        ; The white test is the arbiter: it has not been wrong in any measurement
        ; so far, whereas the bar search still mis-reads some scenes. When the two
        ; disagree, the bar reading is thrown away rather than acted on.
        zoneSaysIn := (haveZone && aimX && Abs(zC - aimX) <= halfW)
        ; Agreement can only be judged on a real reading, so a remembered fish is
        ; treated as agreeing - it is the best information available and the
        ; alternative is the mid-track fallback that caused this round.
        zoneAgrees := (haveZone && aimX && (!fishX || (!!zoneSaysIn = !!onTarget)))

        ; Agreement is strong evidence when the fish is INSIDE - the white test
        ; confirms the bar is really where the search said. It is weak evidence
        ; when the fish is OUTSIDE, because a bar found on scenery is usually far
        ; from the fish as well, and so agrees by coincidence. Give that case a
        ; deadline: steer at it, but stop believing it if no on-target frame
        ; arrives, rather than pushing at a phantom for the whole fight.
        if (onTarget)
            OffSince := 0
        else if (!OffSince)
            OffSince := A_TickCount
        zoneTrusted := (zoneAgrees
            && (!OffSince || A_TickCount - OffSince < Cfg["distrustMs"]))

        if (onTarget) {
            ; The game is telling us the fish is inside the bar. The only job
            ; now is to stay there.
            ProbeUntil := 0
            if (zoneAgrees) {
                ; Nudge toward centring the fish in the bar, which buys the most
                ; margin before it slips out either side.
                aim := aimX + Round(FishVel * Cfg["reelLeadMs"] / 1000)
                lead := zC + Round(ZoneVel * Cfg["reelDampMs"] / 1000)
                err := aim - lead
                deadPx := SW(Cfg["reelDeadPx"])
                if (err > deadPx)
                    HoldMouse()
                else if (err < -deadPx)
                    ReleaseMouse()
                ; Inside the dead zone the button is left alone - but note this
                ; does NOT hold position, it lets the bar keep running at ~385
                ; px/s, which is why the band is only one tick of travel wide.
            } else {
                ; Scoring, but the bar's position is unknown. Alternate so it
                ; hovers instead of drifting off one side.
                if MouseIsDown
                    ReleaseMouse()
                else
                    HoldMouse()
            }
        } else if (zoneTrusted) {
            ; Both signals agree the fish is outside. Drive the bar at the fish,
            ; with no dead zone: we are already losing, so every tick counts.
            ProbeUntil := 0
            aim := aimX + Round(FishVel * Cfg["reelLeadMs"] / 1000)
            if (aim > zC)
                HoldMouse()
            else
                ReleaseMouse()
        } else if (aimX) {
            ; Outside, and the bar's position is not trustworthy. One bit cannot
            ; say WHICH WAY to go, so commit to a direction for a short window
            ; and reverse if it has not paid off. A wrong guess costs one window;
            ; the branch above takes over the moment the readings agree again.
            if (A_TickCount >= ProbeUntil) {
                ProbeDir := (ProbeDir = 1) ? -1 : 1
                ProbeUntil := A_TickCount + Cfg["probeMs"]
            }
            if (ProbeDir = 1)
                HoldMouse()
            else
                ReleaseMouse()
        } else if (haveZone) {
            ; No fish visible and the last reading has gone stale. Only now is
            ; mid-track the best guess - it is where a fish is most likely to
            ; reappear within reach.
            mid := (SX(BOX_TRACK[1]) + SX(BOX_TRACK[3])) // 2
            if (zC < mid - SW(20))
                HoldMouse()
            else if (zC > mid + SW(20))
                ReleaseMouse()
        } else {
            ; Fully blind. Sweep rather than parking against an end stop.
            if MouseIsDown
                ReleaseMouse()
            else
                HoldMouse()
        }

        ; Refresh the overlay from inside the loop: the timer is unreliable here
        ; because this loop rarely yields for long.
        if (Cfg["overlay"] && A_TickCount - LastOvlAt > 100) {
            LastOvlAt := A_TickCount
            try OvlUpdate()
        }

        if ReelTrace {
            aimErr := (fishX && LastZoneX)
                ? (fishX + Round(FishVel * Cfg["reelLeadMs"] / 1000)) - LastZoneX
                : ""
            try FileAppend((A_TickCount - guard) . "," . (fishX ? fishX : "") . ","
                . Round(FishVel) . "," . (haveZone ? zLo : "") . ","
                . (haveZone ? zHi : "") . "," . (haveZone ? zC : "") . ","
                . aimErr . "," . (onTarget ? 1 : 0) . "," . (zoneTrusted ? 1 : 0) . ","
                . (MouseIsDown ? 1 : 0) . "`n",
                A_ScriptDir . "/reeltrace.csv", "UTF-8")
        }
        Sleep Cfg["reelTickMs"]
    }
    ReleaseMouse()
}

; Decide whether the reel that just finished landed its fish.
;
; Called every tick. Does nothing unless a reel has just ended, and that is the
; only time the catch caption is read at all - so a bright patch of scenery in
; the caption box cannot be mistaken for a catch, because nothing is looking.
ResolveReel(canSee := true) {
    global Counters, Cfg, ResolvePend, ResolveUntil, LineOut
    if !ResolvePend
        return
    ; The caption can only be read while Roblox is actually on screen.
    if (canSee && Cfg["detectSuccess"] && HasCaption()) {
        Counters["caught"]++
        ResolvePend := false
        LineOut := false
        LogLine("caught it (" . Counters["caught"] . " landed of "
            . Counters["hooked"] . " hooked)")
        return
    }
    if (A_TickCount >= ResolveUntil) {
        ResolvePend := false
        LineOut := false
        if canSee {
            Counters["lost"]++
            LogLine("lost it (" . Counters["lost"] . " lost of "
                . Counters["hooked"] . " hooked)")
        } else {
            ; The window expired while we could not see the screen, so whether it
            ; landed is genuinely unknown. Calling it a loss would be a guess
            ; recorded as a measurement.
            Counters["unresolved"]++
            LogLine("unresolved — could not see the screen while it landed")
        }
    }
}

; Abandon any fish currently in flight, without guessing its outcome. Used when a
; run stops or the loop is interrupted mid-fight.
DropPendingFish(why) {
    global Counters, Status, ResolvePend, LineOut
    if (ResolvePend || Status = "fish_on") {
        Counters["unresolved"]++
        ResolvePend := false
        LogLine("unresolved (" . why . ")")
    }
    LineOut := false
    Status := ""
}

; ---------------------------------------------------------------- main loop

MainTick() {
    global Running, Status, PrevStatus, Counters, Cfg, StatusSince, NextCastAt
    global LastOvlAt, ResolvePend, ResolveUntil, Draining

    if !Running
        return
    if !RefreshGeometry() {
        SetStatus("no game window")
        return
    }
    if !RobloxIsFront() {
        ReleaseMouse()
        ; Still let a pending fish time out, but flag it unresolved rather than
        ; lost: the caption cannot be read while another window is in front, so
        ; "no caption" carries no information here.
        ResolveReel(false)
        SetStatus("waiting — Roblox not in front")
        return
    }

    if (Cfg["overlay"] && A_TickCount - LastOvlAt > 100) {
        LastOvlAt := A_TickCount
        try OvlUpdate()
    }

    ; Judge the previous reel before anything else. The caption is only ever
    ; looked for inside this window, which is why it cannot be matched against
    ; scenery: while idle, nothing asks.
    ResolveReel()

    s := DetectStatus()
    if (s != Status) {
        if (Status = "fish_on") {
            ; Do not decide yet - the caption has not rendered on this tick.
            ResolvePend := true
            ResolveUntil := A_TickCount + Cfg["resolveMs"]
        }
        if (s = "bait") {
            LogLine("bite — shaking")
            ; NextCastAt is deliberately left alone. Zeroing it here discarded
            ; the bite-wait guard, so a false bite let the loop re-cast while its
            ; line was still out - and a second cast cancels the first. A real
            ; bite ends the wait on its own when fish_on arrives.
        }
        if (s = "fish_on") {
            NextCastAt := 0
            ; A new fight starting while the last one is still unjudged means the
            ; last one got away without a caption.
            if ResolvePend {
                Counters["lost"]++
                ResolvePend := false
            }
            Counters["hooked"]++
            LogLine("hooked — reeling")
        }
        ; Leaving a reel: let the game finish landing the fish before re-casting.
        if (Status = "fish_on" && s != "fish_on")
            NextCastAt := A_TickCount + Cfg["postReelMs"]
        LogLine("state: " . (Status = "" ? "(start)" : Status) . " -> " . s)
        Status := s
        StatusSince := A_TickCount
    }
    SetStatus(FriendlyStatus(s))

    switch s {
        case "fish_on":
            DoReel()
        case "bait":
            ; The ring still gates the response - only answer a prompt that is
            ; actually on screen - but with Enter its exact position no longer
            ; matters, only that it is there.
            DoShake(FindShakeRing())
        case "idle":
            ; Do NOT cast again while a line is already in the water: a second
            ; cast cancels the first. Measured without this guard: 89 casts and
            ; zero bites in 149 seconds.
            ; Never cast while a fish is still being judged - the cast blocks
            ; long enough to swallow the rest of the caption window. And once the
            ; bounded deadline has passed, do not start anything new.
            if (Draining)
                Sleep Cfg["tickMs"]
            else if (ResolvePend)
                Sleep Cfg["tickMs"]
            else if (A_TickCount >= NextCastAt)
                DoCast()
            else
                Sleep Cfg["tickMs"]
        case "casting":
            ; Mid-cast and the button is already released; just wait it out.
            Sleep Jitter(Cfg["tickMs"])
        case "success":
            LogLine("caught one")
            Sleep Jitter(400)
    }
}

FriendlyStatus(s) {
    switch s {
        case "idle":     return "waiting to cast"
        case "casting":  return "casting"
        case "bait":     return "shaking"
        case "fish_on":  return "reeling in"
        case "success":  return "caught one"
    }
    return s
}

; ---------------------------------------------------------------- GUI

BuildGui() {
    global UI, Gui1, Cfg, APP_TITLE

    Gui1 := Gui("+Resize", APP_TITLE)
    Gui1.SetFont("s9", "Segoe UI")
    Gui1.OnEvent("Close", (*) => StopAndExit())

    Gui1.Add("Text", "x12 y10 w60", "Status:")
    UI["status"] := Gui1.Add("Text", "x72 y10 w250 cBlue", "stopped")
    UI["start"] := Gui1.Add("Button", "x330 y6 w80 h26", "Start (F9)")
    UI["start"].OnEvent("Click", (*) => ToggleRun())

    Gui1.Add("Text", "x12 y36 w400 cGray",
        "F9 start/stop   ·   F12 panic exit (always releases the mouse)")

    ; --- counters ---
    Gui1.Add("GroupBox", "x8 y58 w404 h64", "Session")
    UI["counters"] := Gui1.Add("Text", "x18 y78 w384", "casts 0   shakes 0   hooked 0")
    UI["counters2"] := Gui1.Add("Text", "x18 y98 w384", "caught 0   lost 0   runtime 0s")

    ; --- tuning ---
    Gui1.Add("GroupBox", "x8 y128 w404 h280", "Tuning (takes effect immediately)")
    y := 148
    AddSlider("castHoldMs", "Cast hold (ms)",   200, 2500, y), y += 30
    AddSlider("reelTickMs", "Reel speed (ms)",   10,  200, y), y += 30
    AddSlider("reelDeadPx", "Steering dead zone (px)", 2, 80, y), y += 30
    AddSlider("tolWhite",   "White tolerance",    5,   90, y), y += 30
    AddSlider("tolRing",    "Ring tolerance",     5,   90, y), y += 30
    AddSlider("biteWaitMs", "Wait for bite (ms)", 3000, 25000, y), y += 34

    UI["jitter"] := Gui1.Add("CheckBox", "x18 y" . y . " w170 Checked" . Cfg["useJitter"],
        "Randomise timings")
    UI["jitter"].OnEvent("Click", (*) => (Cfg["useJitter"] := UI["jitter"].Value))
    UI["succ"] := Gui1.Add("CheckBox", "x192 y" . y . " w214 Checked" . Cfg["detectSuccess"],
        "Count catches from the caption")
    UI["succ"].OnEvent("Click", (*) => (Cfg["detectSuccess"] := UI["succ"].Value))
    y += 22
    UI["shakeEnter"] := Gui1.Add("CheckBox", "x18 y" . y . " w370 Checked"
        . (Cfg["shakeMethod"] = 2 ? 0 : 1),
        "Answer SHAKE with Enter (off = click the ring)")
    UI["shakeEnter"].OnEvent("Click",
        (*) => (Cfg["shakeMethod"] := UI["shakeEnter"].Value ? 1 : 2))
    y += 22
    UI["overlay"] := Gui1.Add("CheckBox", "x18 y" . y . " w370 Checked" . Cfg["overlay"],
        "Show detection overlay (red = looking here, blue = found it)")
    UI["overlay"].OnEvent("Click", (*) => OvlToggle(UI["overlay"].Value))

    ; --- calibration ---
    Gui1.Add("GroupBox", "x8 y418 w404 h112", "Calibration")
    Gui1.Add("Text", "x18 y438 w388 cGray",
        "Hover the game and press Ctrl+Shift+C to capture the cursor position"
        . "`nand the colour under it. Useful when a Fisch update moves the interface.")
    UI["capture"] := Gui1.Add("Text", "x18 y474 w388", "last capture: (none)")
    UI["test"] := Gui1.Add("Button", "x18 y496 w120 h24", "Test detectors")
    UI["test"].OnEvent("Click", (*) => TestDetectors())
    UI["reset"] := Gui1.Add("Button", "x146 y496 w140 h24", "Reset to defaults")
    UI["reset"].OnEvent("Click", (*) => ResetToDefaults())

    ; --- log ---
    UI["log"] := Gui1.Add("Edit", "x8 y538 w404 h146 ReadOnly +VScroll", "")

    Gui1.Show("w420 h694")
    LogLine("ready. Roblox must be in borderless fullscreen (F11) and in front.")
}

; Put every tuning value back to what the script ships with, and make the
; window agree - otherwise the sliders keep showing the old numbers and the
; panel silently lies about what is in effect.
ResetToDefaults() {
    global Cfg, Defaults, UI, SettingsKept, SettingsMoved
    for k, v in Defaults {
        Cfg[k] := v
        if UI.Has(k) {
            try UI[k].Value := v
            if UI.Has(k . "_v")
                try UI[k . "_v"].Text := v
        }
    }
    ; The checkboxes are named for what they say, not for the key behind them.
    try UI["jitter"].Value := Cfg["useJitter"]
    try UI["succ"].Value := Cfg["detectSuccess"]
    try UI["shakeEnter"].Value := (Cfg["shakeMethod"] = 2 ? 0 : 1)
    try UI["overlay"].Value := Cfg["overlay"]
    OvlToggle(Cfg["overlay"])
    SettingsKept := [], SettingsMoved := []
    SaveSettings()
    LogLine("tuning reset to built-in defaults and saved")
}

AddSlider(key, label, lo, hi, y) {
    global UI, Gui1, Cfg
    Gui1.Add("Text", "x18 y" . y . " w150", label)
    UI[key] := Gui1.Add("Slider", "x170 y" . (y - 4) . " w170 Range" . lo . "-" . hi
        . " ToolTip", Cfg[key])
    UI[key . "_v"] := Gui1.Add("Text", "x346 y" . y . " w60", Cfg[key])
    UI[key].OnEvent("Change", SliderChanged.Bind(key))
}

SliderChanged(key, *) {
    global UI, Cfg
    Cfg[key] := UI[key].Value
    UI[key . "_v"].Value := Cfg[key]
}

SetStatus(text) {
    global UI, Status
    if UI.Has("status")
        UI["status"].Value := text
}

RefreshCounters() {
    global UI, Counters, SessionStart, Cfg
    if !UI.Has("counters")
        return
    secs := SessionStart ? (A_TickCount - SessionStart) // 1000 : 0
    rate := (secs > 30 && Counters["caught"] > 0)
        ? Round(Counters["caught"] * 3600 / secs) : 0
    ; The two numbers the whole effort is judged on. Landed-of-hooked isolates
    ; the reel controller; landed-of-cast covers the whole loop.
    judged := Counters["caught"] + Counters["lost"]
    ofHooked := judged ? Round(Counters["caught"] * 100 / judged) : 0
    ofCasts := Counters["castsOk"]
        ? Round(Counters["caught"] * 100 / Counters["castsOk"]) : 0
    UI["counters"].Value := "casts " . Counters["casts"]
        . "   shakes " . Counters["shakes"]
        . "   hooked " . Counters["hooked"]
    ; `caught` only means anything while caption detection is on, so label it
    ; honestly rather than showing a number that is always zero.
    caughtTxt := Cfg["detectSuccess"]
        ? "caught " . Counters["caught"] . "  lost " . Counters["lost"]
            . (Counters["unresolved"] ? "  unres " . Counters["unresolved"] : "")
            . "  |  " . ofHooked . "% landed  " . ofCasts . "%/cast"
        : "reels finished " . Counters["lost"] . "   (catch counting off)"
    UI["counters2"].Value := caughtTxt
        . "   " . secs . "s"
        . (rate ? "  (" . rate . "/hr)" : "")
}

TestDetectors() {
    if !RefreshGeometry() {
        LogLine("TEST: no Roblox game window found.")
        return
    }
    LogLine("TEST client " . CW . "x" . CH . " at (" . CX . "," . CY . ")"
        . (RobloxIsFront() ? "  [in front]" : "  [NOT in front — reads may show another window]"))
    LogLine("  progress bar : " . (HasProgressBar() ? "FOUND -> fish_on" : "-"))
    LogLine("  hotbar       : " . (HasHotbar() ? "present" : "HIDDEN -> casting/reeling"))
    r := FindShakeRing()
    LogLine("  shake ring   : " . (r ? "FOUND centre ~" . r[1] . "," . r[2] : "-"))
    LogLine("  fish line    : " . ((fx := FindFishX()) ? "x=" . fx : "-"))
    LogLine("  detected     : " . DetectStatus())
}

; =============================================================================
;  Debug overlay
;  Red outlines  = the regions the script searches.
;  Blue squares  = where a detector last matched something.
;
;  Every overlay window is marked WDA_EXCLUDEFROMCAPTURE, so the script's own
;  PixelSearch reads straight through it. Without that the script would detect
;  its own overlay - verified before building this: an un-excluded magenta
;  window was found by PixelSearch, and an excluded one was not.
; =============================================================================

OvlToggle(on) {
    global Cfg, Hits
    Cfg["overlay"] := on ? 1 : 0
    Hits := Map()
    if !on
        OvlHideAll()
}

NoteHit(name, x, y) {
    global Hits, Cfg
    if !Cfg["overlay"]
        return
    Hits[name] := (x || y) ? [x, y] : 0
}

; One thin solid window, used as a rectangle edge or a marker.
OvlMakeWindow(colour) {
    global Cfg
    ; NOTE: do NOT add WS_EX_LAYERED (+E0x80000) here. A layered window whose
    ; transparency is never initialised renders nothing at all - measured: 0
    ; pixels drawn, versus 7200 for the same window without the style.
    ; +E0x20 is WS_EX_TRANSPARENT, which is what makes it click-through.
    ; -DPIScale is essential, not cosmetic. AHK scales Gui coordinates by the
    ; display DPI unless told not to, while PixelSearch reads physical pixels -
    ; so at 125% scaling every box was drawn at 1.25x its position and size, and
    ; the overlay appeared scattered across the screen. Measured as a no-op at
    ; 100%, so it is safe everywhere.
    g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20 +Disabled -DPIScale")
    g.BackColor := colour
    g.Show("NoActivate x-200 y-200 w1 h1")
    if Cfg["overlayHideFromCapture"]
        DllCall("SetWindowDisplayAffinity", "ptr", g.Hwnd, "uint", 0x11)
    return g
}

OvlBuild() {
    global OvlBars, OvlMarks, OvlBuilt
    if OvlBuilt
        return
    ; Four edges per outlined region.
    for name in ["progress", "hotbar", "ring", "track", "caption", "scanline"] {
        for edge in ["t", "b", "l", "r"]
            OvlBars[name . edge] := OvlMakeWindow("Red")
    }
    for name in ["progress", "hotbar", "ring", "zoneLo", "zoneHi", "zoneC",
                 "fish", "onTgt", "caption"]
        OvlMarks[name] := OvlMakeWindow("0080FF")
    OvlBuilt := true
}

OvlHideAll() {
    global OvlBars, OvlMarks
    for _, g in OvlBars
        try g.Hide()
    for _, g in OvlMarks
        try g.Hide()
}

OvlDestroy() {
    global OvlBars, OvlMarks, OvlBuilt
    for _, g in OvlBars
        try g.Destroy()
    for _, g in OvlMarks
        try g.Destroy()
    OvlBars := Map()
    OvlMarks := Map()
    OvlBuilt := false
}

; Draw a rectangle outline from four edge windows.
OvlRect(name, x1, y1, x2, y2) {
    global OvlBars, Cfg
    t := Max(1, Cfg["overlayThickness"])
    w := x2 - x1
    h := y2 - y1
    if (w <= 0 || h <= 0)
        return
    try {
        OvlBars[name . "t"].Show("NoActivate x" . x1 . " y" . y1 . " w" . w . " h" . t)
        OvlBars[name . "b"].Show("NoActivate x" . x1 . " y" . (y2 - t) . " w" . w . " h" . t)
        OvlBars[name . "l"].Show("NoActivate x" . x1 . " y" . y1 . " w" . t . " h" . h)
        OvlBars[name . "r"].Show("NoActivate x" . (x2 - t) . " y" . y1 . " w" . t . " h" . h)
    }
}

OvlMark(name, pt) {
    global OvlMarks
    if !OvlMarks.Has(name)
        return
    g := OvlMarks[name]
    if !pt {
        try g.Hide()
        return
    }
    sz := 12
    try g.Show("NoActivate x" . (pt[1] - sz // 2) . " y" . (pt[2] - sz // 2)
        . " w" . sz . " h" . sz)
}

; Refreshed on its own timer so it never slows the control loop.
OvlUpdate() {
    global Cfg, OvlBuilt, Hits, BOX_PROGRESS, BOX_HOTBAR, BOX_RING, BOX_TRACK
    global BOX_CAPTION, TRACK_IN_X0, TRACK_IN_X1, ZONE_SCAN_Y, RbxHwnd, Running
    global OvlMarks

    if !Cfg["overlay"] {
        if OvlBuilt
            OvlHideAll()
        return
    }
    if !RefreshGeometry() {
        if OvlBuilt
            OvlHideAll()
        return
    }
    OvlBuild()

    ; Only draw while Roblox is actually in front, so the boxes do not float
    ; over other windows.
    if !RobloxIsFront() {
        OvlHideAll()
        return
    }

    DrawBox(nm, b) {
        OvlRect(nm, SX(b[1]), SY(b[2]), SX(b[3]), SY(b[4]))
    }
    DrawBox("progress", BOX_PROGRESS)
    DrawBox("hotbar", BOX_HOTBAR)
    DrawBox("ring", BOX_RING)
    DrawBox("track", BOX_TRACK)
    DrawBox("caption", BOX_CAPTION)
    ; The single row the zone bracketing actually scans.
    OvlRect("scanline", SX(TRACK_IN_X0), SY(ZONE_SCAN_Y) - 1,
            SX(TRACK_IN_X1), SY(ZONE_SCAN_Y) + 1)

    ; When the loop is stopped, nothing else calls the detectors - so the overlay
    ; would show boxes with no hits in them. Run them here (throttled) so the
    ; overlay is useful for checking calibration before pressing Start.
    ; Only re-run detectors when the loop is NOT running. While it is, the
    ; control loop has already populated Hits this tick and re-reading would
    ; double the number of screen captures.
    static idleTick := 0
    if !Running {
        idleTick++
        if (Mod(idleTick, 2) = 0) {
            HasProgressBar()
            HasHotbar()
            FindShakeRing()
            FindZone(&zlo, &zhi, &zc)
            FindFishX()
            HasCaption()
        }
    }

    for name in ["progress", "hotbar", "ring", "zoneLo", "zoneHi", "zoneC",
                 "fish", "onTgt", "caption"]
        OvlMark(name, Hits.Has(name) ? Hits[name] : 0)
}

; ---------------------------------------------------------------- settings

SaveSettings() {
    global Cfg, INI_FILE, REF_W, REF_H, SETTINGS_VERSION, Defaults
    try {
        for k, v in Cfg {
            IniWrite(v, INI_FILE, "tuning", k)
            ; The default this value was saved against, so a future version can
            ; tell a deliberate tuning from an untouched default.
            IniWrite(Defaults.Has(k) ? Defaults[k] : v, INI_FILE, "defaults", k)
        }
        IniWrite(REF_W . "x" . REF_H, INI_FILE, "meta", "referenceResolution")
        IniWrite(FormatTime(, "yyyy-MM-dd HH:mm:ss"), INI_FILE, "meta", "savedAt")
        IniWrite(SETTINGS_VERSION, INI_FILE, "meta", "settingsVersion")
    }
    SaveBoxes()
}

; Detector boxes are overridable from the INI so a machine at a different
; resolution can be recalibrated without editing the script. Values are
; reference (1920x1080) coordinates: "x1,y1,x2,y2".
LoadBoxes() {
    global INI_FILE, BOX_PROGRESS, BOX_HOTBAR, BOX_RING, BOX_TRACK, BOX_CAPTION
    global TRACK_IN_X0, TRACK_IN_X1, ZONE_SCAN_Y
    if !FileExist(INI_FILE)
        return false
    changed := false

    ReadBox(key, ByRef) {
        try {
            raw := IniRead(INI_FILE, "boxes", key, "")
        } catch {
            return 0
        }
        if (raw = "")
            return 0
        parts := StrSplit(raw, ",")
        if (parts.Length != 4)
            return 0
        out := []
        for v in parts {
            v := Trim(v)
            if !IsNumber(v)
                return 0
            out.Push(Integer(v))
        }
        return out
    }

    for key, ref in Map("progress", "BOX_PROGRESS", "hotbar", "BOX_HOTBAR",
                        "ring", "BOX_RING", "track", "BOX_TRACK",
                        "caption", "BOX_CAPTION") {
        got := ReadBox(key, ref)
        if got {
            switch ref {
                case "BOX_PROGRESS": BOX_PROGRESS := got
                case "BOX_HOTBAR":   BOX_HOTBAR := got
                case "BOX_RING":     BOX_RING := got
                case "BOX_TRACK":    BOX_TRACK := got
                case "BOX_CAPTION":  BOX_CAPTION := got
            }
            changed := true
        }
    }
    for key, dflt in Map("trackInX0", TRACK_IN_X0, "trackInX1", TRACK_IN_X1,
                         "zoneScanY", ZONE_SCAN_Y) {
        try {
            raw := IniRead(INI_FILE, "boxes", key, "")
        } catch {
            continue
        }
        if (raw != "" && IsNumber(raw)) {
            if (key = "trackInX0")
                TRACK_IN_X0 := Integer(raw)
            else if (key = "trackInX1")
                TRACK_IN_X1 := Integer(raw)
            else
                ZONE_SCAN_Y := Integer(raw)
            changed := true
        }
    }
    return changed
}

SaveBoxes() {
    global INI_FILE, BOX_PROGRESS, BOX_HOTBAR, BOX_RING, BOX_TRACK, BOX_CAPTION
    global TRACK_IN_X0, TRACK_IN_X1, ZONE_SCAN_Y
    J(b) => b[1] . "," . b[2] . "," . b[3] . "," . b[4]
    try {
        IniWrite(J(BOX_PROGRESS), INI_FILE, "boxes", "progress")
        IniWrite(J(BOX_HOTBAR), INI_FILE, "boxes", "hotbar")
        IniWrite(J(BOX_RING), INI_FILE, "boxes", "ring")
        IniWrite(J(BOX_TRACK), INI_FILE, "boxes", "track")
        IniWrite(J(BOX_CAPTION), INI_FILE, "boxes", "caption")
        IniWrite(TRACK_IN_X0, INI_FILE, "boxes", "trackInX0")
        IniWrite(TRACK_IN_X1, INI_FILE, "boxes", "trackInX1")
        IniWrite(ZONE_SCAN_Y, INI_FILE, "boxes", "zoneScanY")
    }
}

LoadSettings() {
    global Cfg, Defaults, INI_FILE, SETTINGS_VERSION
    global SettingsReset, SettingsKept, SettingsMoved
    if !FileExist(INI_FILE)
        return false

    ver := 0
    try ver := Integer(IniRead(INI_FILE, "meta", "settingsVersion", "0"))
    sameVersion := (ver = SETTINGS_VERSION)

    ; A file with no [defaults] section predates provenance tracking, so there is
    ; no way to tell a tuned value from a stale one. Those are dropped rather
    ; than trusted - that ambiguity is exactly what caused the reelDampMs bug.
    hasProvenance := false
    try hasProvenance := (IniRead(INI_FILE, "defaults", "tickMs", "") != "")
    if (!sameVersion && !hasProvenance) {
        SettingsReset := true
        return false    ; [boxes] still loads: screen geometry stays valid.
    }

    ok := false
    for k, shipped in Defaults {
        got := "", was := ""
        try got := IniRead(INI_FILE, "tuning", k, "")
        try was := IniRead(INI_FILE, "defaults", k, "")
        if (got = "" || !IsNumber(got))
            continue

        if (sameVersion) {
            Cfg[k] := Integer(got)
            ok := true
            continue
        }

        ; Version bump. Keep what the user changed; let the rest move forward.
        userTuned := (was != "" && IsNumber(was) && Integer(got) != Integer(was))
        if (userTuned) {
            Cfg[k] := Integer(got)
            ok := true
            if (Integer(got) != shipped)
                SettingsKept.Push(k . "=" . Integer(got))
        } else if (Integer(got) != shipped) {
            SettingsMoved.Push(k . " " . Integer(got) . "->" . shipped)
        }
    }
    return ok
}

; True when the Roblox client area matches what the detector boxes were
; calibrated against. Logs the fix and returns false when it does not.
;
; This is a hard stop rather than a warning because the failure is silent and
; total: a windowed client is 1920x1017 at (0,23), which shifts BOX_PROGRESS onto
; the hotbar, so the bot reads "already reeling" forever and never casts. Nothing
; in that behaviour points at the window.
ResolutionOk() {
    global CW, CH, REF_W, REF_H, Cfg
    if !Cfg["requireExactRes"]
        return true
    if (CW = REF_W && CH = REF_H)
        return true
    LogLine("REFUSING TO START — Roblox is " . CW . "x" . CH . ", not "
        . REF_W . "x" . REF_H)
    LogLine("  Press F11 in Roblox for borderless fullscreen, then start again.")
    LogLine("  (A title bar makes the client 1920x1017, which shifts every")
    LogLine("   detector onto the wrong part of the screen.)")
    SetStatus("wrong window size — press F11 in Roblox")
    return false
}

; ---------------------------------------------------------------- run control

ToggleRun() {
    global Running
    if Running
        StopRun("stopped by user")
    else
        StartRun()
}

StartRun() {
    global Running, SessionStart, UI, Status, Cfg
    global ReelTicks, ReelOnTicks, ReelPeriodMs, ReelPeriodN, ResolvePend, LineOut
    if !RefreshGeometry() {
        LogLine("cannot start: no Roblox game window. Open Fisch first.")
        SetStatus("no game window")
        return
    }
    if !ResolutionOk() {
        return
    }
    Running := true
    ; Status is deliberately NOT blanked here: doing so destroys the
    ; fish_on -> something edge the resolver hangs off, which silently dropped a
    ; hooked fish on every stop/start. StopRun has already settled any fish.
    ; A run is one measurement, so its diagnostics start clean.
    ReelTicks := 0, ReelOnTicks := 0, ReelPeriodMs := 0, ReelPeriodN := 0
    ResolvePend := false
    ; Permissive at startup so a fight already in progress is still honoured;
    ; from the first resolve onward the cast/resolve cycle governs it.
    LineOut := true
    if !SessionStart
        SessionStart := A_TickCount
    UI["start"].Text := "Stop (F9)"
    LogLine("started")
    ; The overlay timer used to be started only by the interactive startup path,
    ; so headless runfor/reeltrace runs drew no overlay at all. Start it here so
    ; it follows the loop instead of the launch mode.
    if Cfg["overlay"]
        SetTimer(OvlUpdate, 120)
    SetTimer(MainTick, Cfg["tickMs"])
}

StopRun(why := "stopped") {
    global Running, UI
    Running := false
    ; A fish in flight when the loop stops has no observable outcome.
    DropPendingFish("run stopped")
    SetTimer(MainTick, 0)
    ReleaseMouse()
    UI["start"].Text := "Start (F9)"
    SetStatus(why)
    LogLine(why)
}

StopAndExit() {
    StopRun("exiting")
    ExitApp
}

; ---------------------------------------------------------------- hotkeys

F9::ToggleRun()

F12:: {
    ReleaseMouse()
    StopRun("PANIC — mouse released")
    ExitApp
}

^+c:: {
    global UI
    CoordMode "Mouse", "Screen"
    CoordMode "Pixel", "Screen"
    MouseGetPos(&mx, &my)
    col := 0
    try col := PixelGetColor(mx, my)
    fx := CW ? Round((mx - CX) * REF_W / CW) : 0
    fy := CH ? Round((my - CY) * REF_H / CH) : 0
    txt := "screen (" . mx . "," . my . ")  ref (" . fx . "," . fy . ")  "
        . Format("0x{1:06X}", col)
    UI["capture"].Value := "last capture: " . txt
    LogLine("captured " . txt)
}

; ---------------------------------------------------------------- startup

CoordMode "Pixel", "Screen"
CoordMode "Mouse", "Screen"

loaded := LoadSettings()
boxesLoaded := LoadBoxes()

; Headless self-test: `AutoHotkey64.exe fisch-autofisher.ahk selftest`
; Reads every detector once, writes a report next to the script, and exits.
; Sends no input, so it is safe to run at any time — useful for checking
; calibration after a Fisch update without starting the loop.
if (A_Args.Length && StrLower(A_Args[1]) = "selftest") {
    RunSelfTest()
    ExitApp
}

; `doctor [seconds]` - read-only portability and health check. Run this FIRST on
; a new machine. With a seconds argument it watches while you fish by hand, so
; the reel-bar detectors get exercised too.
if (A_Args.Length && StrLower(A_Args[1]) = "ctrltest") {
    secs := (A_Args.Length >= 2 && IsNumber(A_Args[2])) ? Integer(A_Args[2]) : 120
    RunCtrlTest(secs)
    ReleaseMouse()
    ExitApp
}

if (A_Args.Length && StrLower(A_Args[1]) = "doctor") {
    secs := (A_Args.Length >= 2 && IsNumber(A_Args[2])) ? Integer(A_Args[2]) : 0
    RunDoctor(secs)
    ExitApp
}

; Bounded headless run: `... fisch-autofisher.ahk runfor 150`
; Runs the real loop for N seconds, then stops, releases the mouse and writes a
; report. Exists so the loop can be exercised for a fixed, safe window rather
; than being started open-endedly.
global RunForDeadline := 0
; Set once the bounded deadline passes: no new casts are started, but the loop
; keeps ticking so a fish already in flight can be judged.
global Draining  := false
global DrainUntil := 0
; `reeltrace <seconds>`: a bounded run that also records every steering
; decision, so the controller can be judged on data instead of impressions.
if (A_Args.Length >= 2 && StrLower(A_Args[1]) = "reeltrace") {
    ReelTrace := true
    try FileDelete(A_ScriptDir . "/reeltrace.csv")
    try FileAppend("t_ms,fishX,fishVel,zoneLo,zoneHi,zoneC,err,onTgt,trust,held`n",
                   A_ScriptDir . "/reeltrace.csv", "UTF-8")
    BuildGui()
    RunForDeadline := A_TickCount + Integer(A_Args[2]) * 1000
    LogLine("reel trace run: " . A_Args[2] . "s")
    Gui1.Hide()
    if RefreshGeometry() {
        try WinActivate("ahk_id " . RbxHwnd)
        try WinWaitActive("ahk_id " . RbxHwnd, , 3)
        Sleep 500
    }
    StartRun()
    SetTimer(CheckRunForDeadline, 500)
    return
}

if (A_Args.Length >= 2 && StrLower(A_Args[1]) = "runfor") {
    BuildGui()
    RunForDeadline := A_TickCount + Integer(A_Args[2]) * 1000
    LogLine("headless bounded run: " . A_Args[2] . "s")
    Gui1.Hide()          ; keep it hidden so it cannot swallow clicks
    ; Bring Roblox forward, or the loop's own focus guard would just idle.
    if RefreshGeometry() {
        try WinActivate("ahk_id " . RbxHwnd)
        try WinWaitActive("ahk_id " . RbxHwnd, , 3)
        Sleep 500
    }
    StartRun()
    SetTimer(CheckRunForDeadline, 500)
    return          ; headless: skip the interactive startup below
}

CheckRunForDeadline() {
    global RunForDeadline, Counters, SessionStart, UI, Cfg
    global Status, ResolvePend, Draining, DrainUntil
    if (!RunForDeadline || A_TickCount < RunForDeadline)
        return

    ; Ending mid-fight counts a `hooked` that never resolves, which understates
    ; the catch rate and can flip the gate on its own. Stop starting new work,
    ; then wait - bounded - for the fish in flight to be judged.
    if !Draining {
        Draining := true
        DrainUntil := A_TickCount + 30000
        LogLine("deadline reached — letting the fish in flight finish")
    }
    if ((Status = "fish_on" || ResolvePend) && A_TickCount < DrainUntil)
        return

    SetTimer(CheckRunForDeadline, 0)
    StopRun("bounded run finished")
    global ReelTicks, ReelOnTicks, ReelPeriodMs, ReelPeriodN
    out := A_ScriptDir . "/runfor-report.txt"
    try FileDelete(out)
    secs := SessionStart ? (A_TickCount - SessionStart) // 1000 : 0

    hooked := Counters["hooked"], caught := Counters["caught"]
    lost := Counters["lost"], casts := Counters["casts"]
    unres := Counters["unresolved"], castsOk := Counters["castsOk"]
    ; The rate is over fish whose outcome was actually OBSERVED. Fish we could not
    ; see the result of are reported separately rather than assumed lost.
    judged   := caught + lost
    ofHooked := judged  ? Round(caught * 100 / judged, 1)  : 0
    ; Casts that never entered the water are rod-equip failures, not fishing.
    ofCasts  := castsOk ? Round(caught * 100 / castsOk, 1) : 0
    dwell    := ReelTicks ? Round(ReelOnTicks * 100 / ReelTicks, 1) : 0
    period   := ReelPeriodN ? Round(ReelPeriodMs / ReelPeriodN) : 0
    ; Every hooked fish must land in exactly one of the three outcomes. Necessary
    ; but NOT sufficient: several ways of producing a wrong rate keep it intact.
    settled  := (caught + lost + unres = hooked)

    body := "Fisch Auto-Fisher - bounded run verdict`n"
        . "Finished: " . FormatTime(, "yyyy-MM-dd HH:mm:ss")
        . "   runtime " . secs . "s`n"
        . "=====================================================`n`n"
        . "  GATE  landed of hooked : " . ofHooked . "%   of " . judged
        . " judged   (target 90%)  " . (ofHooked >= 90 ? "PASS" : "FAIL") . "`n"
        . "        landed of casts  : " . ofCasts . "%   of " . castsOk
        . " that entered the water   (maximise)`n`n"
        . "  SCOREBOARD HONEST      : " . (settled ? "yes" : "NO - DO NOT TRUST THE RATES")
        . "   (caught " . caught . " + lost " . lost . " + unresolved " . unres
        . " = " . (caught + lost + unres) . ", hooked " . hooked . ")`n"
        . "  sample size            : " . judged . " judged fish"
        . (judged < 20 ? "   << TOO SMALL TO CONCLUDE ANYTHING" : "") . "`n"
        . "  casts that failed      : " . (casts - castsOk) . " of " . casts
        . "   (rod not equipped / cast did not register)`n`n"
        . "  reel dwell on target   : " . dwell . "%   of " . ReelTicks . " decisions`n"
        . "  actual control period  : " . period . " ms"
        . "   (reelTickMs setting is " . Cfg["reelTickMs"] . ")`n`n"
        . "counters:`n"
    for k, v in Counters
        body .= "  " . k . " = " . v . "`n"
    body .= "`ntuning in effect:`n"
    for k, v in Cfg
        body .= "  " . k . " = " . v . "`n"
    body .= "`nLog:`n" . (UI.Has("log") ? UI["log"].Value : "(none)") . "`n"
    try FileAppend(body, out, "UTF-8")
    ExitApp
}

; =============================================================================
;  Doctor - portability and health check. Sends NO input; safe to run any time.
;  `AutoHotkey64.exe fisch-autofisher.ahk doctor [seconds]`
;
;  With a seconds argument it also WATCHES for that long, so you can fish by
;  hand while it runs and it will report whether every detector fired at least
;  once. Detectors for the reel bar can only be checked while a fish is hooked,
;  which is why watching matters.
; =============================================================================
RunDoctor(watchSeconds := 0) {
    global REF_W, REF_H, CX, CY, CW, CH, RbxHwnd, Cfg, INI_FILE
    global COL_TRACK, COL_FISH, COL_WHITE, COL_RING, ZONE_SCAN_Y
    global BOX_PROGRESS, BOX_HOTBAR, BOX_RING, BOX_TRACK, BOX_CAPTION
    global TRACK_IN_X0, TRACK_IN_X1

    out := A_ScriptDir . "/doctor-report.txt"
    try FileDelete(out)
    problems := 0
    warnings := 0

    W(t := "") => FileAppend(t . "`n", out, "UTF-8")
    Fail(msg, fix) {
        W("  [PROBLEM] " . msg)
        W("            fix: " . fix)
    }
    Warn(msg, note) {
        W("  [warn]    " . msg)
        W("            " . note)
    }
    Pass(msg) => W("  [ok]      " . msg)

    W("Fisch Auto-Fisher - doctor")
    W("Run at: " . FormatTime(, "yyyy-MM-dd HH:mm:ss"))
    W(StrReplace(Format("{1:80}", ""), " ", "="))
    W()

    ; ---------------------------------------------------------- 1. AutoHotkey
    W("1. AutoHotkey")
    W("   version " . A_AhkVersion . "   " . (A_PtrSize = 8 ? "64-bit" : "32-bit")
        . "   " . (A_IsAdmin ? "elevated" : "not elevated"))
    if (SubStr(A_AhkVersion, 1, 1) != "2") {
        Fail("this needs AutoHotkey v2, found v" . A_AhkVersion,
             "install AutoHotkey v2 from autohotkey.com and run the script with it")
        problems++
    } else
        Pass("AutoHotkey v2 present")
    if A_IsAdmin
        Warn("running elevated", "not required; only matters if Roblox is elevated too")
    W()

    ; --------------------------------------------------- 2. Windows DPI scaling
    W("2. Windows display scaling")
    pct := Round(A_ScreenDPI * 100 / 96)
    W("   system DPI " . A_ScreenDPI . "  (" . pct . "%)")
    if (A_ScreenDPI != 96) {
        Warn("display scaling is " . pct . "%, not 100%",
             "Windows may report window sizes in scaled units. If the readings"
             . " below look wrong, set this display to 100% in"
             . " Settings > System > Display > Scale.")
        warnings++
    } else
        Pass("scaling is 100%")
    W()

    ; --------------------------------------------------------- 3. Roblox window
    W("3. Roblox window")
    if !RefreshGeometry() {
        Fail("no visible Roblox game window found",
             "start Roblox and join Fisch, then run doctor again. Note that Roblox"
             . " can be running with no game open - the process alone is not enough.")
        problems++
        W()
        W("Cannot continue without a game window.")
        FileAppend("`n" . problems . " problem(s), " . warnings . " warning(s).`n",
                   out, "UTF-8")
        return
    }
    WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . RbxHwnd)
    W("   process " . WinGetProcessName("ahk_id " . RbxHwnd)
        . "   class " . WinGetClass("ahk_id " . RbxHwnd))
    W("   window  " . ww . "x" . wh . " at (" . wx . "," . wy . ")")
    W("   client  " . CW . "x" . CH . " at (" . CX . "," . CY . ")")
    W("   chrome  dx=" . (CX - wx) . " dy=" . (CY - wy))
    Pass("Roblox window located")

    if ((CX - wx) != 0 || (CY - wy) != 0) {
        Warn("the game has a title bar / border (not borderless fullscreen)",
             "press F11 in Roblox. Windowed mode gives a shorter, non-16:9 game"
             . " area, and the interface positions shift with it.")
        warnings++
    } else
        Pass("borderless fullscreen (no title bar)")

    if !RobloxIsFront() {
        Warn("Roblox is not the foreground window right now",
             "fine for doctor, which only reads - but the loop cannot send input"
             . " unless Roblox is in front, and anything covering it gets read"
             . " instead of the game.")
    }
    W()

    ; ------------------------------------------------------ 4. Geometry mapping
    W("4. Geometry mapping (this is what portability depends on)")
    aspect := Round(CW / CH, 4)
    scale := Round(CW / REF_W, 4)
    W("   calibrated for " . REF_W . "x" . REF_H . " (16:9, aspect 1.7778)")
    W("   this machine   " . CW . "x" . CH . "  aspect " . aspect
        . "  scale " . scale . "x")
    if (Abs(aspect - 1.7778) > 0.02) {
        Fail("the game area is not 16:9 (aspect " . aspect . ")",
             "every position here is stored as a fraction of a 16:9 window, so a"
             . " different shape moves the interface relative to those fractions."
             . " Use borderless fullscreen on a 16:9 display, or expect to"
             . " recalibrate with Ctrl+Shift+C.")
        problems++
    } else {
        Pass("aspect ratio is 16:9 - reference positions map correctly")
        if (Abs(scale - 1.0) > 0.01)
            Pass("resolution differs from the reference but scales cleanly at "
                . scale . "x")
    }
    if (CX < 0 || CY < 0) {
        Warn("the game window sits at a negative screen coordinate",
             "handled correctly - the script reads the window origin rather than"
             . " assuming (0,0) - but worth knowing on a multi-monitor setup.")
    }
    W()

    ; ------------------------------------------------------- 5. Settings file
    W("5. Settings file")
    if FileExist(INI_FILE) {
        savedRes := ""
        try savedRes := IniRead(INI_FILE, "meta", "referenceResolution", "")
        Warn("a settings file exists and OVERRIDES the built-in defaults",
             "if it came from another machine its tuning may not suit this one."
             . " Delete fisch-autofisher.ini to get the shipped defaults back."
             . (savedRes ? "  (saved against " . savedRes . ")" : ""))
        warnings++
    } else
        Pass("no settings file - using the shipped defaults")
    W()

    ; --------------------------------------------------------- 6. Detectors
    W("6. Detectors")
    W("   Some can only be verified at the right moment: the reel-bar detectors")
    W("   need a fish actually hooked. Run `doctor 60` and fish by hand for a")
    W("   minute to exercise all of them.")
    W()

    seen := Map("hotbar", 0, "ring", 0, "progress", 0, "zone", 0, "fish", 0,
                "caption", 0)
    zoneW := "", fishSeenAt := ""
    deadline := A_TickCount + watchSeconds * 1000
    loop {
        if !RefreshGeometry()
            break
        if HasHotbar()
            seen["hotbar"]++
        if FindShakeRing()
            seen["ring"]++
        if HasProgressBar()
            seen["progress"]++
        if FindZone(&zl, &zh, &zc) {
            seen["zone"]++
            zoneW := (zh - zl)
        }
        if (fx := FindFishX()) {
            seen["fish"]++
            fishSeenAt := fx
        }
        if HasCaption()
            seen["caption"]++
        if (A_TickCount >= deadline)
            break
        Sleep 150
    }

    samples := 0
    for k, v in seen
        samples := Max(samples, v)

    if (watchSeconds > 0)
        W("   watched for " . watchSeconds . "s")

    ; CONTRADICTION CHECK. The hotbar is hidden while a fish is being reeled in,
    ; so "hotbar visible AND progress bar visible" is a state the game cannot be
    ; in. When it happens, a detector box is landing on the wrong thing - which
    ; is exactly what a different resolution causes, and exactly what an earlier
    ; version of this doctor missed while reporting all clear.
    if (seen["hotbar"] > 0 && seen["progress"] > 0) {
        Fail("contradiction: the hotbar AND the reel progress bar are both visible",
             "the game hides the hotbar while reeling, so these cannot both be"
             . " true. A detector box is landing on the wrong interface element."
             . " Most likely the game area is not 1920x1080: Roblox's interface"
             . " does not scale purely proportionally, so at other resolutions"
             . " the hotbar grows and bleeds into the progress-bar box."
             . " Either play at 1920x1080, or recalibrate the boxes - see the"
             . " [boxes] section of fisch-autofisher.ini.")
        problems++
    }

    if (seen["hotbar"] > 0)
        Pass("hotbar found - the interface is where the script expects it")
    else {
        Fail("hotbar NOT found",
             "this is the single most important check. It means the script cannot"
             . " see the game's interface where it expects it. Most likely causes:"
             . " not borderless fullscreen; a different Roblox UI scale; or the"
             . " game not actually on screen.")
        problems++
    }

    if (watchSeconds > 0) {
        W()
        W("   detector             times seen   verdict")
        Report(name, key, needsWhat) {
            n := seen[key]
            W(Format("   {1:-20} {2:10}   ", name, n)
                . (n > 0 ? "ok" : "not seen - " . needsWhat))
        }
        Report("hotbar", "hotbar", "should be visible whenever not casting/reeling")
        Report("SHAKE ring", "ring", "only appears during the shake phase")
        Report("progress bar", "progress", "only appears while a fish is hooked")
        Report("reel zone", "zone", "only appears while a fish is hooked")
        Report("fish marker", "fish", "only meaningful while a fish is hooked")
        Report("catch caption", "caption", "only after landing a fish")
        if (seen["zone"] > 0) {
            expect := SW(232)
            W()
            W("   reel zone width measured " . zoneW . " px, expected about "
                . expect . " px at this resolution")
            if (Abs(zoneW - expect) > expect * 0.35) {
                Warn("the zone width is well off the expected value",
                     "steering may be inaccurate. Worth re-checking the track"
                     . " coordinates with Ctrl+Shift+C.")
                warnings++
            }
        }
    }
    W()

    ; ------------------------------------------------------------- summary
    W(StrReplace(Format("{1:80}", ""), " ", "="))
    if (problems = 0 && warnings = 0)
        W("ALL CLEAR - nothing found that would stop this working here.")
    else
        W(problems . " problem(s), " . warnings . " warning(s). Problems will stop"
            . " it working; warnings are worth reading.")
    W()
    W("Detector boxes in use (reference 1920x1080 coords; override in the")
    W("[boxes] section of fisch-autofisher.ini):")
    ShowBox(n, b) => W(Format("   {1:-10}", n) . b[1] . "," . b[2] . "," . b[3] . "," . b[4])
    ShowBox("progress", BOX_PROGRESS)
    ShowBox("hotbar", BOX_HOTBAR)
    ShowBox("ring", BOX_RING)
    ShowBox("track", BOX_TRACK)
    ShowBox("caption", BOX_CAPTION)
    W("   trackInX0 " . TRACK_IN_X0 . "   trackInX1 " . TRACK_IN_X1
        . "   zoneScanY " . ZONE_SCAN_Y)
    W()
    W("Things doctor cannot check for you:")
    W("  - Roblox's own UI scale setting. If it differs from the machine this was")
    W("    calibrated on, every interface position shifts. The hotbar check above")
    W("    is the best proxy: if that passes, the scale almost certainly matches.")
    W("  - Roblox graphics quality, which changes lighting and can shift colours.")
    W("    The detectors look for bright interface against dark interface rather")
    W("    than exact colours, so this is usually survivable.")
    W("  - Whether a rod is equipped. The loop detects a failed cast and re-equips.")
}

; =============================================================================
;  Control-response experiment:  `... fisch-autofisher.ahk ctrltest [seconds]`
;
;  Two competing models of the reel minigame:
;    STATE   - holding the button pushes the bar right, releasing lets it fall
;              left. Bar velocity depends on whether the button is DOWN.
;    IMPULSE - each click nudges the bar right and it falls left on its own.
;              Bar velocity depends on the CLICK RATE, and a sustained hold does
;              little after the first instant.
;
;  These predict different things, so applying fixed patterns and measuring the
;  bar's velocity distinguishes them. Sends only left clicks; releases on exit.
; =============================================================================
RunCtrlTest(seconds := 120) {
    global Cfg, Running, RbxHwnd, NextCastAt

    out := A_ScriptDir . "/ctrltest-report.txt"
    try FileDelete(out)
    W(t := "") => FileAppend(t . "`n", out, "UTF-8")

    W("Reel control-response experiment")
    W("Run at: " . FormatTime(, "yyyy-MM-dd HH:mm:ss"))
    W()

    if !RefreshGeometry() {
        W("FAIL: no Roblox game window.")
        return
    }
    try WinActivate("ahk_id " . RbxHwnd)
    try WinWaitActive("ahk_id " . RbxHwnd, , 3)
    Sleep 400

    ; Patterns: [label, clicksPerSecond].  0 = hold the button down for the whole
    ; phase.  -1 = keep it released for the whole phase.
    patterns := [["HOLD (button down)", 0]
               , ["RELEASE (button up)", -1]
               , ["click 20/sec", 20]
               , ["click 12/sec", 12]
               , ["click 6/sec", 6]
               , ["click 3/sec", 3]]

    PHASE_MS := 1300
    deadline := A_TickCount + seconds * 1000
    results := Map()
    for pat in patterns
        results[pat[1]] := []

    round := 0
    while (A_TickCount < deadline) {
        ; Wait for a reel to be in progress.
        if !HasProgressBar() {
            ; Fish our way to a reel: this mode does not run the main loop.
            ReleaseMouse()
            if FindShakeRing() {
                DoShake(0)
            } else if (HasHotbar() && A_TickCount >= NextCastAt) {
                DoCast()
            }
            Sleep 120
            continue
        }
        round++
        W("--- reel " . round . " ---")

        for pat in patterns {
            if (A_TickCount >= deadline || !HasProgressBar())
                break
            label := pat[1]
            rate := pat[2]

            ; Let the previous phase settle, then record a start position.
            ReleaseMouse()
            Sleep 120
            if !FindZone(&aLo, &aHi, &aC)
                continue
            t0 := A_TickCount

            ; Apply the pattern for one phase.
            nextClick := 0
            while (A_TickCount - t0 < PHASE_MS) {
                if (rate = 0) {
                    HoldMouse()
                } else if (rate = -1) {
                    ReleaseMouse()
                } else {
                    ; Discrete clicks at the requested rate.
                    if (A_TickCount >= nextClick) {
                        ReleaseMouse()
                        Click
                        nextClick := A_TickCount + Round(1000 / rate)
                    }
                }
                Sleep 8
            }
            ReleaseMouse()

            if !FindZone(&bLo, &bHi, &bC)
                continue
            dt := A_TickCount - t0
            if (dt < 200)
                continue
            v := Round((bC - aC) * 1000 / dt)
            results[label].Push(v)
            W(Format("   {1:-22}", label) . " bar moved "
                . Format("{1:6}", Round(bC - aC)) . " px in " . dt . " ms"
                . "  ->  " . Format("{1:6}", v) . " px/sec")
        }
    }
    ReleaseMouse()

    W()
    W("=========================================================")
    W("SUMMARY - median bar velocity per input pattern")
    W("=========================================================")
    W(Format("{1:-22}", "pattern") . Format("{1:>10}", "samples")
        . Format("{1:>14}", "median px/s"))
    for pat in patterns {
        arr := results[pat[1]]
        if !arr.Length {
            W(Format("{1:-22}", pat[1]) . Format("{1:>10}", 0) . "          n/a")
            continue
        }
        sorted := []
        for v in arr
            sorted.Push(v)
        ; simple insertion sort
        loop sorted.Length {
            i := A_Index
            loop sorted.Length - i {
                j := A_Index
                if (sorted[j] > sorted[j + 1]) {
                    tmp := sorted[j]
                    sorted[j] := sorted[j + 1]
                    sorted[j + 1] := tmp
                }
            }
        }
        med := sorted[(sorted.Length + 1) // 2]
        W(Format("{1:-22}", pat[1]) . Format("{1:>10}", arr.Length)
            . Format("{1:>14}", med))
    }
    W()
    W("How to read this:")
    W("  If HOLD is strongly positive and clicking is weaker, the game is")
    W("  STATE driven and the current hold/release controller is right.")
    W("  If HOLD is near zero and faster clicking gives more rightward")
    W("  movement, the game is IMPULSE driven and the controller should")
    W("  modulate CLICK RATE instead.")
}

RunSelfTest() {
    out := A_ScriptDir . "/selftest-report.txt"
    try FileDelete(out)
    W(t := "") => FileAppend(t . "`n", out, "UTF-8")

    W("Fisch Auto-Fisher — detector self-test")
    W("Run at: " . FormatTime(, "yyyy-MM-dd HH:mm:ss"))
    W("AHK " . A_AhkVersion . "   admin=" . A_IsAdmin)
    W()
    if !RefreshGeometry() {
        W("FAIL: no visible Roblox game window. Open Fisch first.")
        return
    }
    W("Roblox client : " . CW . "x" . CH . " at (" . CX . "," . CY . ")")
    W("Display DPI   : " . A_ScreenDPI
        . (A_ScreenDPI = 96 ? "  (100% scaling)"
                            : "  (" . Round(A_ScreenDPI * 100 / 96) . "% scaling)"))
    W("Matches 1920x1080 calibration: " . ((CW = 1920 && CH = 1080) ? "YES" : "NO"))
    W("Roblox in front: " . (RobloxIsFront() ? "yes"
        : "NO — reads may be showing whatever covers it"))
    W()
    ; Where each box actually lands, in screen pixels. The overlay is hidden
    ; from screen capture on purpose, so on another machine this is the only way
    ; to see whether the boxes are where they should be.
    W("detector boxes, as resolved on this screen:")
    for name, b in Map("progress", BOX_PROGRESS, "hotbar", BOX_HOTBAR,
                       "ring", BOX_RING, "track", BOX_TRACK,
                       "caption", BOX_CAPTION) {
        W(Format("  {1:-9} x {2}..{3}   y {4}..{5}   ({6} x {7} px)",
                 name, SX(b[1]), SX(b[3]), SY(b[2]), SY(b[4]),
                 SX(b[3]) - SX(b[1]), SY(b[4]) - SY(b[2])))
    }
    W("  reel scan row : y " . SY(ZONE_SCAN_Y)
        . "   track interior x " . SX(TRACK_IN_X0) . ".." . SX(TRACK_IN_X1))
    W()
    W("detector readings:")
    W("  progress bar (fish_on) : " . (HasProgressBar() ? "FOUND" : "-"))
    W("  hotbar present         : " . (HasHotbar() ? "yes" : "NO -> casting or reeling"))
    r := FindShakeRing()
    W("  shake ring (bait)      : " . (r ? "FOUND, centre ~" . r[1] . "," . r[2] : "-"))
    if FindZone(&zl, &zh, &zc)
        W("  reel zone              : x " . zl . ".." . zh . "  centre " . zc
            . "  width " . (zh - zl))
    else
        W("  reel zone              : -")
    W("  fish line              : " . ((fx := FindFishX()) ? "x=" . fx : "-"))
    W("  catch caption          : " . (HasCaption() ? "FOUND" : "-")
        . "   (detector unverified; off by default)")
    W()
    W("NOTE: 'reel zone' and 'fish line' are only meaningful while actually")
    W("reeling. With no bar on screen they match scenery, which is harmless")
    W("because both are read only after the progress bar confirms fish_on.")
    W()
    W("=> Status would be: " . DetectStatus())
    W()
    W("tuning in effect:")
    for k, v in Cfg
        W("  " . k . " = " . v)
}

BuildGui()
if loaded
    LogLine("settings loaded from fisch-autofisher.ini")
else if SettingsReset
    LogLine("saved tuning predates version stamping — built-in defaults in use")
else
    LogLine("no settings file — using built-in defaults (1920x1080 reference)")
if SettingsKept.Length
    LogLine("kept your tuning: " . Join(SettingsKept, ", "))
if SettingsMoved.Length
    LogLine("updated to new defaults: " . Join(SettingsMoved, ", "))

if !RefreshGeometry()
    LogLine("WARNING: no Roblox game window found yet.")
else
    LogLine("Roblox client " . CW . "x" . CH . " at (" . CX . "," . CY . ")"
        . ((CW = 1920 && CH = 1080)
            ? "  — matches calibration"
            : "  — WRONG SIZE. Press F11 in Roblox for borderless fullscreen."))

SetTimer(RefreshCounters, 500)
SetTimer(OvlUpdate, 120)

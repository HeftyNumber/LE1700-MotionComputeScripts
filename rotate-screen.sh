#!/bin/bash
# ==============================================================================
# Unified Screen & Digitizer Rotation Control Script
# Target Device: Motion Computing LE1700 Tablet (Native 1400x1050 Panel)
# ==============================================================================
#
# DESCRIPTION:
#   This script safely coordinates screen rotation alongside input hardware maps
#   (Wacom stylus, eraser, bezel mouse pointer, and directional bezel buttons).
#   It implements a 1.0001 transformation matrix override for ALL modes to leverage
#   modern software rendering, bypassing legacy Intel hardware rendering artifacts.
#
# USAGE EXAMPLES (Map these execution formats straight to your XFCE shortcuts):
#
#   1. Cyclical Sequential Loops (Perfect for single-button toggles):
#      ./rotate-screen.sh cw    -> Step sequentially Clockwise (Default behavior)
#      ./rotate-screen.sh ccw   -> Step sequentially Counter-Clockwise
#
#   2. Absolute Targets (Jump straight to an orientation from a specific key):
#      ./rotate-screen.sh normal   -> Force default Landscape layout (With Hack)
#      ./rotate-screen.sh right    -> Force primary Portrait layout (CW)
#      ./rotate-screen.sh inverted -> Force upside-down Landscape layout (Half)
#      ./rotate-screen.sh left     -> Force secondary Portrait layout (CCW)
#
# ==============================================================================

# --- TARGET HARDWARE CORE DEFINITIONS ---
STYLUS="Wacom Serial Penabled Pen stylus"
ERASER="Wacom Serial Penabled Pen eraser"
MOUSE="pointer:Semtech Semtech PixKey"
OUTPUT="LVDS-1"

# Extract live display tracking status from the X server active geometry map
ROT=$(xrandr -q --verbose | sed -n '/ connected /s/.*) \([a-z]*\) (.*/\1/p')

apply_settings() {
    # Arguments array sequence map reference:
    # $1=xrandr_dir $2=wacom_dir $3=mouse_matrix $4=k_up $5=k_left $6=k_right $7=k_down $8=W $9=H
    local xr_rot=$1 wa_rot=$2 matrix=$3 k_up=$4 k_left=$5 k_right=$6 k_down=$7
    local W=$8 H=$9

    # 1. ATOMIC ROTATION ALTERATION (GLOBAL SOFTWARE RENDERING HACK)
    # Every orientation layout now enforces the 1.0001 transform matrix to bypass
    # legacy hardware driver display artifacts. To keep transitions snappy and
    # prevent double-flashing, we only clear deep panning variables when moving
    # back into default 'normal' landscape boundaries.
    if [ "$xr_rot" = "normal" ]; then
        xrandr --output "$OUTPUT" --panning 0x0 --rotation normal --fb "${W}x${H}" --transform 1,0,0,0,1,0,0,0,1.0001
    else
        xrandr --output "$OUTPUT" --rotation "$xr_rot" --fb "${W}x${H}" --transform 1,0,0,0,1,0,0,0,1.0001
    fi

    # 2. X11 GEOMETRY CONVERGENCE DELAY
    # Crucial race condition protector. Allows the XFCE window manager and the
    # X server a moment to settle into the updated desktop dimensions before
    # attempting to attach input tracking bounding boxes.
    sleep 1.0

    # 3. WACOM COORDINATE ALIGNMENT & HARD-MAPPING
    # Iterates over active inputs, strips scaling matrix drift risks,
    # corrects orientation variables, and safely links boundaries directly
    # inside our new display frame boundaries.
    for DEV in "$STYLUS" "$ERASER"; do
        if xinput list --name-only | grep -q "^$DEV$"; then
            xinput set-prop "$DEV" "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1
            xsetwacom set "$DEV" ResetArea
            xsetwacom set "$DEV" rotate "$wa_rot"
            xsetwacom set "$DEV" MapToOutput "$OUTPUT"
        fi
    done

    # 4. PHYSICAL AUXILIARY BEZEL POINTER CORRECTION
    # Adjusts the hardware scaling map matrix for the Integrated Bezel Mouse pointer.
    xinput set-prop "$MOUSE" "Coordinate Transformation Matrix" $matrix

    # 5. HARDWARE INTEGRATED NAVIGATION BUTTON SYNC
    # Dynamically remaps directional scan-codes so Up/Down/Left/Right inputs
    # remain physically intuitive relative to how you are holding the tablet.
    xmodmap -e "keycode $k_up = Up" -e "keycode $k_left = Left" \
            -e "keycode $k_right = Right" -e "keycode $k_down = Down"

    # 6. GRAPHICAL DESKTOP ENVIRONMENT RE-MAINTENANCE
    # Tells XFCE's desktop manager to snap icons cleanly to grid guidelines
    # matching the freshly updated screen edge aspect changes.
    if command -v xfdesktop >/dev/null 2>&1; then
        xfdesktop --arrange
        xfdesktop --reload
    fi
}

# --- CENTRAL REUSABLE CONFIGURATION PROFILES ---
# Parameter map structure template:
# [xrandr_mode] [wacom_mode] [pointer_matrix_string] [key_up] [key_left] [key_right] [key_down] [width] [height]
set_normal()   { apply_settings "normal"   "none" "1 0 0 0 1 0 0 0 1"   111 113 114 116 1400 1050; }
set_right()    { apply_settings "right"    "cw"   "0 1 0 -1 0 1 0 0 1"  114 111 116 113 1050 1400; }
set_inverted() { apply_settings "inverted" "half" "-1 0 1 0 -1 1 0 0 1" 116 114 113 111 1400 1050; }
set_left()     { apply_settings "left"     "ccw"  "0 -1 1 1 0 0 0 0 1"  113 116 111 114 1050 1400; }

# --- INPUT ARGV PROCESSING ---
# Standardize parameters into lowercase strings for flexible execution parsing
COMMAND=$(echo "$1" | tr '[:upper:]' '[:lower:]')

case "$COMMAND" in
    # --- ROUTING PATTERN BLOCK A: ABSOLUTE SPECIFIC TARGETING ---
    normal)   set_normal ;;
    right)    set_right ;;
    inverted) set_inverted ;;
    left)     set_left ;;

    # --- ROUTING PATTERN BLOCK B: RELATIVE COUNTER-CLOCKWISE CYCLING ---
    ccw)
        case "$ROT" in
            normal)   set_left ;;
            left)     set_inverted ;;
            inverted) set_right ;;
            *)        set_normal ;;
        esac
        ;;

    # --- ROUTING PATTERN BLOCK C: RELATIVE CLOCKWISE CYCLING (DEFAULT FALLBACK) ---
    cw|*)
        case "$ROT" in
            normal)   set_right ;;
            right)    set_inverted ;;
            inverted) set_left ;;
            *)        set_normal ;;
        esac
        ;;
esac

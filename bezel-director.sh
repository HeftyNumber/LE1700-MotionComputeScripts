#!/bin/bash
# ==============================================================================
# Bezel Director: True Spatial Absolute Alignment Matrix Wrapper
# Target Device: Motion Computing LE1700 Tablet (Native 1400x1050 Panel)
# ==============================================================================
#
# DESCRIPTION:
#   Because the main 'rotate-screen.sh' script dynamically alters 'xmodmap' to
#   keep arrow keys oriented relative to your eyes, the *physical* frame buttons
#   change what string they send to XFCE whenever the screen spins.
#
#   This director script acts as an absolute spatial interpreter. It intercepts
#   the shifting string sent by XFCE, reads the tablet's current orientation,
#   reverses the rotation math, and figures out exactly which physical button
#   location you pressed on the bezel frame.
#
# PHYSICAL BEZEL TARGET MAP:
#   * Pushing the Physical TOP button (closest to ceiling) -> Forces NORMAL mode
#   * Pushing the Physical RIGHT button (closest to right wall) -> Forces RIGHT mode
#   * Pushing the Physical BOTTOM button (closest to desk) -> Forces INVERTED mode
#   * Pushing the Physical LEFT button (closest to left wall) -> Forces LEFT mode
#
# ==============================================================================
# XFCE APPLICATION SHORTCUT SETUP INSTRUCTIONS:
# ==============================================================================
#
#   To use this system, map your physical "Square" bezel button to trigger your
#   5-second modifier script (the one that simulates Ctrl+Alt+Shift+Super via
#   xdotool).
#
#   Next, open 'XFCE Settings' -> 'Keyboard' -> 'Application Shortcuts' and
#   create these 4 explicit entries. Capture the keys by tapping your Square
#   button followed quickly by the corresponding direction key:
#
#   1. Command: $HOME/.myconfig/MotionComputeScripts/bezel-director.sh up
#      Shortcut Trigger: Ctrl+Alt+Shift+Super+Up
#
#   2. Command: $HOME/.myconfig/MotionComputeScripts/bezel-director.sh right
#      Shortcut Trigger: Ctrl+Alt+Shift+Super+Right
#
#   3. Command: $HOME/.myconfig/MotionComputeScripts/bezel-director.sh down
#      Shortcut Trigger: Ctrl+Alt+Shift+Super+Down
#
#   4. Command: $HOME/.myconfig/MotionComputeScripts/bezel-director.sh left
#      Shortcut Trigger: Ctrl+Alt+Shift+Super+Left
#
#   Important Note for XFCE Shortcuts:** XFCE application shortcut input fields
#   execute commands directly without invoking a shell interpreter. Therefore,
#   environment variables (like `$HOME`) and tilde (`~`) shortcuts will not expand
#   correctly. Please use your full absolute path (replacing `username` with your
#   actual login name, e.g., `/home/username/.myconfig/MotionComputeScripts/...`).
#
# ==============================================================================

# Parse the incoming string argument from XFCE and normalize it to lower-case
RELATIVE_DIR=$(echo "$1" | tr '[:upper:]' '[:lower:]')
ROTATION_SCRIPT="$HOME/.myconfig/MotionComputeScripts/rotate-screen.sh"

# Extract the live display tracking status from the X server active geometry map
CURRENT_ROT=$(xrandr -q --verbose | sed -n '/ connected /s/.*) \([a-z]*\) (.*/\1/p')

# Fail-safe default fallback in case xrandr returns an empty or unparseable string
if [ -z "$CURRENT_ROT" ]; then CURRENT_ROT="normal"; fi

# Decode the changing xmodmap string inputs back into absolute physical directions
case "$CURRENT_ROT" in
    normal)
        # --- BASELINE LANDSCAPE (Standard Orientation) ---
        # The screen is upright. Modifiers match physical directions perfectly.
        case "$RELATIVE_DIR" in
            up)    $ROTATION_SCRIPT normal ;;    # Physical Top Button Pressed
            right) $ROTATION_SCRIPT right ;;     # Physical Right Button Pressed
            down)  $ROTATION_SCRIPT inverted ;;  # Physical Bottom Button Pressed
            left)  $ROTATION_SCRIPT left ;;      # Physical Left Button Pressed
        esac
        ;;

    right)
        # --- PORTRAIT 90° CLOCKWISE (Turned Right) ---
        # Screen rotated CW. Hands shifted by xmodmap.
        case "$RELATIVE_DIR" in
            left)  $ROTATION_SCRIPT normal ;;    # Physical Top Button Pressed
            up)    $ROTATION_SCRIPT right ;;     # Physical Right Button Pressed
            right) $ROTATION_SCRIPT inverted ;;  # Physical Bottom Button Pressed
            down)  $ROTATION_SCRIPT left ;;      # Physical Left Button Pressed
        esac
        ;;

    inverted)
        # --- LANDSCAPE 180° UPSIDE-DOWN (Inverted Layout) ---
        # Screen completely upside down. Hand inputs are mirrored by xmodmap.
        case "$RELATIVE_DIR" in
            down)  $ROTATION_SCRIPT normal ;;    # Physical Top Button Pressed
            left)  $ROTATION_SCRIPT right ;;     # Physical Right Button Pressed
            up)    $ROTATION_SCRIPT inverted ;;  # Physical Bottom Button Pressed
            right) $ROTATION_SCRIPT left ;;      # Physical Left Button Pressed
        esac
        ;;

    left)
        # --- PORTRAIT 90° COUNTER-CLOCKWISE (Turned Left) ---
        # Screen rotated CCW. Hands shifted by xmodmap.
        case "$RELATIVE_DIR" in
            right) $ROTATION_SCRIPT normal ;;    # Physical Top Button Pressed
            down)  $ROTATION_SCRIPT right ;;     # Physical Right Button Pressed
            left)  $ROTATION_SCRIPT inverted ;;  # Physical Bottom Button Pressed
            up)    $ROTATION_SCRIPT left ;;      # Physical Left Button Pressed
        esac
        ;;
esac

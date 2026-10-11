#!/bin/bash
# ==============================================================================
# Bezel Application & Orientation Selector Menu (Stylus & Wheel Optimized)
# Target Device: Motion Computing LE1700 Tablet (Native 1400x1050 Panel)
# ==============================================================================
#
# DESCRIPTION:
#   This script launches a lightweight graphical GTK dialog menu using Zenity.
#   It allows the user to select an application and target orientation using either
#   the tablet's hardware bezel navigation buttons or a Wacom stylus pen.
#
# INTERACTION METHOD:
#   * STYLUS: Single-tap to highlight an item and click OK, or DOUBLE-TAP any
#             menu line item to instantly execute the rotation and application.
#   * WHEEL BUTTONS: Press Up/Down to navigate rows, and press the Center Enter
#                    button to select.
#
# XFCE SHORTCUT SETUP INSTRUCTIONS:
#   1. Open 'XFCE Settings' -> 'Keyboard' -> 'Application Shortcuts'.
#   2. Click 'Add' to create a new shortcut mapping.
#   3. Command: $HOME/.myconfig/MotionComputeScripts/bezel-apps.sh
#   4. Trigger: Press your physical "Circle" bezel button when prompted.
#
#   Important Note for XFCE Shortcuts:** XFCE application shortcut input fields
#   execute commands directly without invoking a shell interpreter. Therefore,
#   environment variables (like `$HOME`) and tilde (`~`) shortcuts will not expand
#   correctly. Please use your full absolute path (replacing `username` with your
#   actual login name, e.g., `/home/username/.myconfig/MotionComputeScripts/...`).
#
# ==============================================================================

# --- PATH & COMMAND DEFINITIONS ---
ROTATION_SCRIPT="$HOME/.myconfig/MotionComputeScripts/rotate-screen.sh"
PDF_XCHANGE_CMD="/usr/bin/pdf-xchange"

# INTEL 945GM COMPATIBILITY LAYER:
# Modern GTK applications try to create hardware-accelerated OpenGL contexts.
# The legacy Intel Mobile 945GM graphics driver throws rendering errors on modern
# kernels if this happens. Forcing the backend to 'x11' routes drawing safely
# through standard X11 core protocols, preventing crashes.
export GDK_RENDERING_BACKEND=x11

# --- DIALOG BOX CREATION ---
# --list: Creates a column-based list choice window.
# --hide-header: Disables the column title bar to maximize vertical space.
# --width / --height: Set to 450x420 pixels to ensure all 6 text lines and windows
#                     buttons are fully drawn on screen without clipping.
SELECTION=$(zenity --list \
    --title="Tablet Workflow Picker" \
    --text="Select a workflow (or double-tap with your stylus):" \
    --column="Selection Layout" \
    --hide-header \
    "1. Xournal++ (Primary Portrait - Right)" \
    "2. Calibre (Primary Portrait - Right)" \
    "3. PDF-XChange (Primary Portrait - Right)" \
    "4. Xournal++ (Secondary Portrait - Left)" \
    "5. Calibre (Secondary Portrait - Left)" \
    "6. PDF-XChange (Secondary Portrait - Left)" \
    --width=450 --height=420)

# --- CANCELLATION PROTECTOR ---
# If the user clicks 'Cancel', hits the Escape key, or closes the window frame
# manually, Zenity returns an empty string. This check safely halts execution
# to prevent unwanted screen flips or accidental tool launches.
if [ -z "$SELECTION" ]; then
    exit 0
fi

# --- WORKFLOW PARSING & EXECUTION ---
# Matches the selected text against the item numbers and handles backgrounding
# via '&' so the applications don't block or freeze your window manager.
case "$SELECTION" in
    *"1."*)
        $ROTATION_SCRIPT right
        xournalpp &
        ;;
    *"2."*)
        $ROTATION_SCRIPT right
        env QTWEBENGINE_CHROMIUM_FLAGS="--disable-gpu" calibre &
        ;;
    *"3."*)
        $ROTATION_SCRIPT right
        $PDF_XCHANGE_CMD &
        ;;
    *"4."*)
        $ROTATION_SCRIPT left
        xournalpp &
        ;;
    *"5."*)
        $ROTATION_SCRIPT left
        env QTWEBENGINE_CHROMIUM_FLAGS="--disable-gpu" calibre &
        ;;
    *"6."*)
        $ROTATION_SCRIPT left
        $PDF_XCHANGE_CMD &
        ;;
esac

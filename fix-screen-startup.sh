#!/bin/bash
# LE1700 Startup Fix: Force software rendering to prevent artifacts

STYLUS="Wacom Serial Penabled Pen stylus"
ERASER="Wacom Serial Penabled Pen eraser"
MOUSE="pointer:Semtech Semtech PixKey"
OUTPUT="LVDS-1"

# 1. Force software rendering by applying a 1.0001 transform
xrandr --output "$OUTPUT" --rotation normal --fb 1400x1050 --transform 1,0,0,0,1,0,0,0,1.0001
sleep 0.5

# 2. Reset and Align Wacom Input (Fixed ResetParameters error)
for DEV in "$STYLUS" "$ERASER"; do
    xsetwacom set "$DEV" ResetArea 
    xsetwacom set "$DEV" Rotate none
    xsetwacom set "$DEV" MapToOutput "$OUTPUT"
done

# 3. Align Bezel Mouse (Fixed ambiguity error using 'pointer:' prefix)
xinput set-prop "$MOUSE" "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1

# 4. Fix the desktop icons in case last shutdown was in a rotated state
sleep 2                 # Provide time for window manager to adjust
xfdesktop --arrange     # Rearrange the icons
xfdesktop --reload      # Refresh the screen

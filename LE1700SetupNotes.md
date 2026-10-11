## Motion Computing LE1700 Linux Configuration Guide & Technical Notes

Released in 2007, the **[Motion Computing LE1700](https://www.google.com/url?sa=t&source=web&rct=j&opi=89978449&url=CAESrQEB6zswFUsPgn2TWDxO1rYX1uYrJNNLyJVLfRaprCLf5VMV6JIcP0U6c2lfYGezr5OGNuoWZgy5atM8Qismgy06oRz9t_8ASEaAxayEicyxA9Vx_5xWQmb1yYDXQK8d8rC_W3-7GRnjCHtg64-GS1bCvNuTVe_p2wH7-sE11B_tmKV-O0xl4NWMnHoDSJSIvLy3eimaJnabABkLKR9N1mLmpwCwdW6bgmcpo4M7Ig&ved=2ahUKEwiZ8c7a4vuWAxXOGFkFHdgMD8YQFnoECBoQAQ&uoh=2&usg=AOvVaw3ATNSXp7IDr14iY6YOapph)** is a high-end, semi-rugged slate tablet PC primarily designed for mobile professionals in industries like healthcare and field service. It features a 12.1-inch **SXGA+** display with a resolution of **1400x1050** and utilizes **Wacom** active digitizer technology, making it a popular legacy choice for digital artists due to its precise pen pressure sensitivity. Powered by **Intel Core 2 Duo** or Core Solo processors, the device includes a built-in fingerprint reader that doubles as a trackpad, integrated Wi-Fi, Bluetooth, and optional mobile broadband. Despite weighing roughly **3.3 lbs**, its slim, fan-cooled design offers extensive connectivity, including USB 2.0, VGA, DVI-D, and a specialized docking connector for desktop use via the [FlexDock docking station](https://www.barcodesinc.com/media/pdf/Motion-Computing/le1700.pdf).

------------------------------
## 1. System Installation & Memory Architecture## Base Installation

* OS: Arch Linux (installed cleanly via archinstall).
* Desktop Environment: XFCE is selected to explicitly minimize graphical composition overhead on the integrated Intel Mobile 945GM/GMS chipset.

## The 3GB Usable Memory Hardware Barrier
The LE1700 platform suffers from a hardware constraint regarding addressable memory. Even with a 64-bit Core 2 Duo CPU and 4GB of physical RAM installed, the operating system will only report between 3.0GB and 3.2GB of usable space.

* 32-Bit Memory Controller: The Intel 945GM chipset features a hard-coded 32-bit memory address controller capping its total address universe at exactly 4GB.
* No Memory Remapping: Modern chipsets can "remap" physical RAM addresses blocked by Memory-Mapped I/O (MMIO) hardware structures (GPU, PCI busses, BIOS) to fields above the 4GB mark. The 945GM lacks the physical circuitry to support remapping.
* PAE/64-Bit Ineffectiveness: Because the system controller itself cannot handle lines above 4GB, a 64-bit kernel or PAE cannot bypass this limit. The top ~800MB of RAM remains permanently invisible.
* Mitigation: A swap file is configured to provide stability during high multitasking demands on this limited ceiling.

------------------------------
## 2. Low-Level Bezel Button Remapping (udev hwdb)
Standard X11 installations map the device D-pad and Power switches out of the box. However, the physical Circle and Square bezel buttons send raw scancodes that are dropped before reaching the X server.
To catch them permanently, they are mapped to unassigned higher function keys (F13 and F14) via the systemd hardware database.
## Configuration File
Create a new file named /etc/udev/hwdb.d/90-le1700-buttons.hwdb with the following content:

# Match the AT Keyboard controller interface on the Motion LE1700
evdev:atkbd:dmi:bvn*:bvr*:bd*:svnMotion*pvr*:rvn*:rn*:rvr*:cvn*:cvr*:*
 KEYBOARD_KEY_f4=f13
 KEYBOARD_KEY_f9=f14

(Note: The leading single space before the KEYBOARD_KEY declarations is syntactically mandatory).
## Apply Configuration Without Rebooting

sudo systemd-hwdb update
sudo udevadm trigger

This forces the hardware database layer to load immediately, exposing F13 (Square Button) and F14 (Circle Button) to X11.
------------------------------
## 3. The Software Rendering Transformation Hack
The Intel Mobile 945GM graphics driver produces severe rendering artifacts, screen tearing, inability to move the mouse in some rotated screen locations due to rotation coordinate mismatches, and trailing mouse cursors when using standard hardware-accelerated X11 rotation parameters. To bypass these broken hardware-accelerated paths, the system uses an intentional matrix scaling override:

--transform 1,0,0,0,1,0,0,0,1.0001

## Why It Works
By applying a coordinate transformation matrix that scales the resolution dimensions by an unnoticeable factor of 0.01%, the X server determines the active target display size is no longer "normal."
This mathematical trick forces the display configuration to drop out of the broken Intel GPU overlay routine and fall back to a highly stable ShadowFB (Software Framebuffer) rendering path handled by the CPU. It eliminates ghosting and graphical corruption entirely across all states.
------------------------------
## 4. Consolidated Production Scripts
To keep input components perfectly synchronized without coordinate drift or race conditions, the configuration scripts have been unified into three core files located at ~/.myconfig/MotionComputeScripts/.
## Script 1: fix-screen-startup.sh
This script must run automatically at login using XFCE Session and Startup -> Application Autostart. It forces software rendering mode immediately upon desktop entry, clearing any corrupted states left behind if the tablet was shut down while rotated.

#!/bin/bash# LE1700 Startup Fix: Force software rendering to prevent artifacts

STYLUS="Wacom Serial Penabled Pen stylus"
ERASER="Wacom Serial Penabled Pen eraser"
MOUSE="pointer:Semtech Semtech PixKey"
OUTPUT="LVDS-1"
### 1. Force software rendering by applying a 1.0001 transform
xrandr --output "$OUTPUT" --rotation normal --fb 1400x1050 --transform 1,0,0,0,1,0,0,0,1.0001
sleep 0.5
### 2. Reset and Align Wacom Inputfor DEV in "$STYLUS" "$ERASER"; do
    xsetwacom set "$DEV" ResetArea 
    xsetwacom set "$DEV" Rotate none
    xsetwacom set "$DEV" MapToOutput "$OUTPUT"done
### 3. Align Bezel Mouse Pointer
xinput set-prop "$MOUSE" "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1
### 4. Refresh Desktop Layout
sleep 2
xfdesktop --arrange
xfdesktop --reload

## Script 2: rotate-screen.sh
The unified master rotation framework. It handles absolute targets alongside relative transitions in a single atomic pass to eliminate rotation lag spikes.

#!/bin/bash# Unified Screen & Digitizer Rotation Control Script (rotate-screen.sh)

STYLUS="Wacom Serial Penabled Pen stylus"
ERASER="Wacom Serial Penabled Pen eraser"
MOUSE="pointer:Semtech Semtech PixKey"
OUTPUT="LVDS-1"

ROT=$(xrandr --verbose | sed -n '/ connected /s/.*) \([a-z]*\) (.*/\1/p')

apply_settings() {
    local xr_rot=$1 wa_rot=$2 matrix=$3 k_up=$4 k_left=$5 k_right=$6 k_down=$7
    local W=$8 H=$9

    if [ "$xr_rot" = "normal" ]; then
        xrandr --output "$OUTPUT" --panning 0x0 --rotation normal --fb "${W}x${H}" --transform 1,0,0,0,1,0,0,0,1.0001
    else
        xrandr --output "$OUTPUT" --rotation "$xr_rot" --fb "${W}x${H}" --transform 1,0,0,0,1,0,0,0,1.0001
    fi

    sleep 1.0

    for DEV in "$STYLUS" "$ERASER"; do
        if xinput list --name-only | grep -q "^$DEV$"; then
            xinput set-prop "$DEV" "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1
            xsetwacom set "$DEV" ResetArea
            xsetwacom set "$DEV" rotate "$wa_rot"
            xsetwacom set "$DEV" MapToOutput "$OUTPUT"
        fi
    done

    xinput set-prop "$MOUSE" "Coordinate Transformation Matrix" $matrix
    
    xmodmap -e "keycode $k_up = Up" -e "keycode $k_left = Left" \
            -e "keycode $k_right = Right" -e "keycode $k_down = Down"

    if command -v xfdesktop >/dev/null 2>&1; then
        xfdesktop --arrange
        xfdesktop --reload
    fi
}

set_normal()   { apply_settings "normal"   "none" "1 0 0 0 1 0 0 0 1"   111 113 114 116 1400 1050; }
set_right()    { apply_settings "right"    "cw"   "0 1 0 -1 0 1 0 0 1"  114 111 116 113 1050 1400; }
set_inverted() { apply_settings "inverted" "half" "-1 0 1 0 -1 1 0 0 1" 116 114 113 111 1400 1050; }
set_left()     { apply_settings "left"     "ccw"  "0 -1 1 1 0 0 0 0 1"  113 116 111 114 1050 1400; }

COMMAND=$(echo "$1" | tr '[:upper:]' '[:lower:]')
case "$COMMAND" in
    normal)   set_normal ;;
    right)    set_right ;;
    inverted) set_inverted ;;
    left)     set_left ;;
    ccw)
        case "$ROT" in
            normal)   set_left ;;
            left)     set_inverted ;;
            inverted) set_right ;;
            *)        set_normal ;;
        esac
        ;;
    cw|*)
        case "$ROT" in
            normal)   set_right ;;
            right)    set_inverted ;;
            inverted) set_left ;;
            *)        set_normal ;;
        esac
        ;;esac

## Script 3: bezel-director.sh
An absolute spatial mapping middleman. Because rotate-screen.sh shifts the D-pad strings via xmodmap to match your changing eye perspective, this script intercepts the dynamic string outputs, reverses the orientation math, and ensures clicking toward a specific wall always triggers the same absolute layout direction.

#!/bin/bash# Spatial Absolute Alignment Matrix Wrapper (bezel-director.sh)

RELATIVE_DIR=$(echo "$1" | tr '[:upper:]' '[:lower:]')
ROTATION_SCRIPT="/home/mfw/.myconfig/MotionComputeScripts/rotate-screen.sh"

CURRENT_ROT=$(xrandr --verbose | sed -n '/ connected /s/.*) \([a-z]*\) (.*/\1/p')if [ -z "$CURRENT_ROT" ]; then CURRENT_ROT="normal"; fi
case "$CURRENT_ROT" in
    normal)
        case "$RELATIVE_DIR" in
            up)    $ROTATION_SCRIPT normal ;;
            right) $ROTATION_SCRIPT right ;;
            down)  $ROTATION_SCRIPT inverted ;;
            left)  $ROTATION_SCRIPT left ;;
        esac
        ;;
    right)
        case "$RELATIVE_DIR" in
            left)  $ROTATION_SCRIPT normal ;;
            up)    $ROTATION_SCRIPT right ;;
            right) $ROTATION_SCRIPT inverted ;;
            down)  $ROTATION_SCRIPT left ;;
        esac
        ;;
    inverted)
        case "$RELATIVE_DIR" in
            down)  $ROTATION_SCRIPT normal ;;
            left)  $ROTATION_SCRIPT right ;;
            up)    $ROTATION_SCRIPT inverted ;;
            right) $ROTATION_SCRIPT left ;;
        esac
        ;;
    left)
        case "$RELATIVE_DIR" in
            right) $ROTATION_SCRIPT normal ;;
            down)  $ROTATION_SCRIPT right ;;
            left)  $ROTATION_SCRIPT inverted ;;
            up)    $ROTATION_SCRIPT left ;;
        esac
        ;;esac

## Script 4: bezel-apps.sh
Tied to the physical Circle button, this triggers a hardware-safe, non-accelerated Zenity choice box optimized for Wacom stylus double-tapping and D-pad navigation. It handles target display pivoting and program execution concurrently.

#!/bin/bash# Bezel Application & Orientation Selector Menu (bezel-apps.sh)

ROTATION_SCRIPT="/home/mfw/.myconfig/MotionComputeScripts/rotate-screen.sh"
PDF_XCHANGE_CMD="/usr/bin/pdf-xchange"

export GDK_RENDERING_BACKEND=x11

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
if [ -z "$SELECTION" ]; then
    exit 0fi
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
        ;;esac

## Script 5: alternate-button.sh
Tied to the Square bezel button, this temporary modifier holds down the Hyper Combo keys via xdotool to dynamically shift shortcut environments without colliding with standard keyboard typing layouts.

#!/bin/sh# Tied to Square Button (F13) - Holds modifier combo for 5 seconds
xdotool keydown shift+ctrl+alt+super
sleep 5
xdotool keyup shift+ctrl+alt+super

------------------------------
## 5. XFCE Application Shortcut Mappings
Assign the scripts within Settings -> Keyboard -> Application Shortcuts using the following parameters:

| Input Trigger Action / Physical Key Combo | Assigned Target Script Path Command |
|---|---|
| Square Button (F13) | /home/mfw/.myconfig/MotionComputeScripts/alternate-button.sh |
| Circle Button (F14) | /home/mfw/.myconfig/MotionComputeScripts/bezel-apps.sh |
| Square + D-Pad Up (Ctrl+Alt+Shift+Super+Up) | /home/mfw/.myconfig/MotionComputeScripts/bezel-director.sh up |
| Square + D-Pad Right (Ctrl+Alt+Shift+Super+Right) | /home/mfw/.myconfig/MotionComputeScripts/bezel-director.sh right |
| Square + D-Pad Down (Ctrl+Alt+Shift+Super+Down) | /home/mfw/.myconfig/MotionComputeScripts/bezel-director.sh down |
| Square + D-Pad Left (Ctrl+Alt+Shift+Super+Left) | /home/mfw/.myconfig/MotionComputeScripts/bezel-director.sh left |
| Dot Button (Left Bezel Edge) | Default: xfce4-session-logout (Launches exit prompt options) |
| X Button | Default: Escape key emulation |
| Center Navigation Pad Button | Default: Enter key emulation |

------------------------------
## 6. Reserved Future Expansion Space
The hardware chord combination Square + Circle (evaluating to the background string signature Ctrl+Alt+Shift+Super+F14) remains entirely unassigned inside the desktop shortcut configuration manager. This combination is explicitly reserved for future custom expansions, such as setting up an On-Screen Keyboard (OSK) utility toggle, system audio adjustments, or screen backlighting scripts.


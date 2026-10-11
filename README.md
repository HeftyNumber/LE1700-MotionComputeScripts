# Motion Computing LE1700 Linux Configuration Guide

This repository contains the complete hardware database configuration files, automated shell scripts, and documentation rules required to run an optimized **Arch Linux** installation with an **XFCE Desktop Environment** on the legacy **Motion Computing LE1700 Tablet PC** (released in 2007).

## Hardware Background & Challenges
The LE1700 is an iconic, semi-rugged slate tablet PC featuring a high-density **12.1-inch 1400x1050 (SXGA+) display** and a high-precision **Wacom serial active digitizer screen**. However, installing a modern Linux distribution exposes two major legacy hardware constraints:
1. **Intel Mobile 945GM GPU Artifacts:** The hardware rendering pipelines of the legacy Intel driver produce severe desktop layout artifacts and stuttering on modern kernels. 
2. **Unrecognized Bezel Controls:** While the D-pad and Power/Reboot buttons work instantly out of the box, the physical "Square" and "Circle" bezel buttons are completely ignored by X11/Xorg by default.
3. **Wacom Input Pointer Drift:** Standard rotation methods cause coordinate transformation mismatch drift between the display grid boundaries and the stylus/eraser tips.

**Solution:** This repository provides an automated software rendering transform hack (`1.0001` scale override) that forces perfectly smooth graphics performance along with a custom spatial decoding matrix script to provide absolute frame-button navigation tracking.

---

## 🛠 Repository File Structure

```text
├── 90-le1700-buttons.hwdb   # Low-level systemd-udev rule mapping physical scancodes to X11 keys
├── alternate_button.sh      # Core "Shift Modifier" simulation using xdotool (Tied to Square)
├── fix-screen-startup.sh    # Post-login initialization script for XFCE autostart profiles
├── rotate-screen.sh         # Unified master rotation control logic (Handles X11, Wacom, and D-pad)
├── bezel-director.sh        # Spatial absolute mapping interpreter (Decodes changing xmodmap strings)
└── bezel-apps.sh            # Graphical GTK picker menu for apps + orientations (Tied to Circle)
```

---

## 🚀 Step-by-Step Installation & Configuration

### Step 1: Base Linux Dependencies
Ensure your base system is up to date and install the critical drivers and utility dependencies:
```bash
sudo pacman -Syu xf86-input-wacom xorg-xrandr xorg-xinput xorg-xmodmap xdotool zenity
```

### Step 2: Unlocking the Bezel Buttons (Hardware Layer)
The Linux kernel registers the raw physical scancodes of the "Square" and "Circle" keys, but standard desktop environments drop them. To map them permanently to non-conflicting virtual function keys (`F13` and `F14`), deploy the provided `.hwdb` file.

1. Copy the rules file to your system configuration folder:
   ```bash
   sudo cp 90-le1700-buttons.hwdb /etc/udev/hwdb.d/90-le1700-buttons.hwdb
   ```
   *(Note: The leading single space before the `KEYBOARD_KEY` properties inside the file is syntactically mandatory).*

2. Reload the system hardware database map and trigger the udev rule manually without rebooting:
   ```bash
   sudo systemd-hwdb update
   sudo udevadm trigger
   ```

### Step 3: Script Deployment & Workspace Setup
1. Create your local system scripts configuration subdirectory:
   ```bash
   mkdir -p ~/.myconfig/MotionComputeScripts/
   ```
2. Move all `.sh` scripts from this repository into that folder and ensure they have global execution permissions configured:
   ```bash
   chmod +x ~/.myconfig/MotionComputeScripts/*.sh
   ```

### Step 4: Automating Software Rendering on Boot
To prevent screen corruption, artifacts, and lag during your desktop session start, append the `fix-screen-startup.sh` utility to your XFCE configuration profile:
1. Navigate to **XFCE Settings** -> **Session and Startup** -> **Application Autostart**.
2. Click **Add** and fill in the properties:
   * **Name:** LE1700 Software Render Initializer
   * **Command:** `/home/username/.myconfig/MotionComputeScripts/fix-screen-startup.sh`
   * **Trigger:** Set to run automatically on *Log In*.

---

## 🕹 XFCE Integration & Key Bindings Matrix

Open **XFCE Settings** -> **Keyboard** -> **Application Shortcuts** to bind your physical tablet buttons to your automated shell scripts. 

> **Important Note for XFCE Shortcuts:** XFCE application shortcut input fields execute commands directly without invoking a shell interpreter. Therefore, environment variables (like `$HOME`) and tilde (`~`) shortcuts will not expand correctly. Please use your full absolute path (replacing `username` with your actual login name, e.g., `/home/username/.myconfig/MotionComputeScripts/...`).

Follow the mapping instructions below:

### 1. The Multiplier Key (The "Square" Bezel Button)
* **Command:** `/home/username/.myconfig/MotionComputeScripts/alternate_button.sh`
* **Trigger Shortcut:** Press your physical **Square Button** (Registers natively as `F13`).
* *How it works:* Pressing this button executes `xdotool` to hold down a safe Hyper Key combo (`Ctrl+Alt+Shift+Super`) for 5 seconds, multiplying what your other bezel buttons can do.

### 2. Absolute Screen Layout Triggers (Square + D-Pad Arrows)
Because `rotate-screen.sh` uses `xmodmap` to dynamically turn the directional keys so they stay intuitive to your eyes, the string signature sent to XFCE changes as the display spins. The `bezel-director.sh` script automatically calculates this math. 

Create these 4 shortcuts. Trigger them by pressing your **Square Button** followed quickly by the target **D-Pad Direction Key**:

| Custom Target Script Command | Resulting Captured XFCE Trigger | Resulting Screen Alignment Effect |
| :--- | :--- | :--- |
| `/.../bezel-director.sh up` | `Ctrl+Alt+Shift+Super+Up` | **Force Normal Landscape Mode** (Ceiling side up) |
| `/.../bezel-director.sh right` | `Ctrl+Alt+Shift+Super+Right` | **Force Primary Portrait Mode** (Right side up) |
| `/.../bezel-director.sh down` | `Ctrl+Alt+Shift+Super+Down` | **Force Inverted Landscape Mode** (Desk side up) |
| `/.../bezel-director.sh left` | `Ctrl+Alt+Shift+Super+Left` | **Force Secondary Portrait Mode** (Left side up) |

*Note: Pressing the same absolute location twice sequentially will keep the layout locked safely in place without toggling or flipping.*

### 3. Workflow App & Orientation Menu (The "Circle" Bezel Button)
* **Command:** `/home/username/.myconfig/MotionComputeScripts/bezel-apps.sh`
* **Trigger Shortcut:** Press your physical **Circle Button** (Registers natively as `F14`).
* *How it works:* Launches an Intel-compatible, non-GL accelerated Zenity dialog showing a clean reading profile list. 
* *Interaction:* You can navigate options using your D-Pad and Center Enter key, or simply **double-tap options with your Wacom stylus pen** to automatically pivot the display frame and pop open **Xournal++**, **Calibre**, or **PDF-XChange (via Wine)**. Note: Xournal++, Calibre, and PDF-XChange need to be installed separately.

---

## 🔮 Future Expansion Layout Note
The system configuration actively reserves the physical key chord combo **`Square + Circle`** (which maps behind the scenes to an active X11 interpretation sequence of `Ctrl+Alt+Shift+Super+F14`). This shortcut is explicitly preserved for custom macro extensions, future on-screen keyboard (OSK) toggles, or screen brightness sliders.

---

## 📄 License & Attribution
Configured and curated for the Arch Linux environment on legacy Motion Computing hardware. Feel free to fork, expand, or adapt for other legacy Wacom Penable slate architectures (such as the LE1600 or LS800 series).

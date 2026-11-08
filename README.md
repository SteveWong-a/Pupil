<h1 align="center">
  <br>
  Pupil
  <br>
</h1>

<h3 align="center">Native macOS menu bar & notch security sentinel for solo study sessions</h3>

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-black.svg" alt="MIT License">
  <img src="https://img.shields.io/badge/macOS-15%2B-black.svg" alt="macOS 15+">
  <img src="https://img.shields.io/badge/Swift_6-SwiftUI_%2B_AppKit-black.svg" alt="Swift 6">
</p>

**Pupil** is a native macOS security sentinel built in **Swift 6, SwiftUI, and AppKit**. Designed for students and solo workers in libraries or cafes, Pupil lives quietly in your macOS menu bar and MacBook notch—monitoring on-device iris gaze, MagSafe/USB-C power unplugs, spatial camera lift & displacement (for open-lid grab & walk attacks on battery), and clamshell lid closures without any Electron or web wrapper bloat.

---

## Four Response Levels

| Level | Trigger | Native macOS Response |
| :--- | :--- | :--- |
| **1. Armed Deterrence** | Armed from Menu Bar (`⌘A`) or Settings header | Menu bar glyph flips to `eye.slash.fill`; IOKit power, clamshell, and Vision spatial lift anchor arm |
| **2. Gaze Warning** | Sustained gaze toward screen inside camera ROI (Apple `Vision` iris + head pose) | MacBook notch drops dark pill status indicator; optional instant Screen Privacy Blur obscures display content while gaze lingers |
| **3. Tamper Countdown** | MagSafe/USB-C charger unplugged (`IOPSCopyPowerSourcesInfo`), sustained spatial lift/occlusion ($> 1.2\text{s}$), or screen locked | Notch expands with an amber countdown; inline Touch ID or Keychain PIN disarms |
| **4. PIN-Latched Siren** | Clamshell lid closed (`AppleClamshellState`) or countdown expires | `IOPMAssertion` holds sleep while `AVAudioEngine` synthesizes a dual-tone siren until PIN/Touch ID disarm |

---

## Native macOS Architecture

* **Dockless Menu Bar Agent (`NSApplication.ActivationPolicy.accessory`)**: Runs silently in `NSStatusBar.system` with zero Dock clutter. Opening **Settings… (`⌘,`)** reveals a native window and automatically returns to `.accessory` mode when closed.
* **System Settings UI Craft**: Built with `NSVisualEffectView` (`.sidebar` vibrancy + saturation filter), unified transparent `NSToolbar`, progressive header blur (`ProgressiveHeaderBlur`), grouped translucent cards, and a floating bottom capsule tab bar with two-finger trackpad swipe navigation.
* **Hardware Notch & Dynamic Island Overlay**: Uses a non-activating `NSPanel` at `CGShieldingWindowLevel() + 1` with concave top-corner flares (`NotchShape`) aligned to `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea`, falling back to a continuous-corner Dynamic Island pill on notchless displays.
* **Zero-Dependency Native Vision & Spatial Lift Detector**:
  * **Iris & Gaze Dwell**: `VNDetectFaceRectanglesRequest` and `VNDetectFaceLandmarksRequest` (`leftPupil`, `rightPupil`, `leftEye`, `rightEye`, `yaw`, `pitch`) at a battery-friendly 10 FPS with fast dwell timing (`0.5s`, `1.0s`, `1.5s`, `2.0s`, `3.0s`) and `Ultra` peripheral shoulder-surfing sensitivity (90% wide camera ROI).
  * **Screen Content Privacy Blur & Armed Input Sentry**: Instant deep frosted-glass privacy blur (95% obsidian scrim + within-window vibrancy) that completely obscures confidential display contents while an unauthorized person looks at your screen, clearing automatically as soon as they look away. Touching any keyboard key or clicking the mouse while armed immediately locks the screen with the frosted privacy shield and challenges for Keychain PIN or Touch ID disarm.
  * **Spatial Lift & Walk Sentry**: Closes the "Unplugged Open-Lid Grab & Walk" theft blindspot on battery power by capturing a Frame 0 reference anchor and metric depth scale $Z_0$ via inter-pupillary distance.
  * **Face-Masked Upper-Background Registration**: Focuses registration on the static top 25% ROI (ceiling/upper walls) while masking out moving face regions, measuring global translation $\|\Delta \mathbf{t}\|$ and homography warp using `VNTranslationalImageRegistrationRequest` and `VNHomographicImageRegistrationRequest`.
  * **Table-Bump Rejection & Lens Occlusion Protection**: Suppresses transient $< 0.5\text{s}$ desk bumps while escalating continuous displacement or lens occlusion (mean luminance and variance near zero) lasting $> 1.2\text{s}$ to the tamper countdown.
  * **100% On-Device Privacy**: All frame processing remains strictly transient in memory—zero frames, crops, or landmarks are ever saved to disk or transmitted over the network.
* **Keychain & Touch ID Security**: Disarm PINs are salted and SHA-256 hashed in the macOS Keychain (`Security` framework) alongside `LocalAuthentication` Touch ID verification.

---

## Download & Installation

Just like Glance, Pupil is packaged into a single standalone drag-and-drop macOS disk image (`Pupil.dmg`):

1. **Download**: Grab the latest **`Pupil.dmg`** from GitHub Releases (or generate it locally with `./scripts/build-dmg.sh`).
2. **Install**: Open `Pupil.dmg` and drag **Pupil.app** into your `/Applications` folder.
3. **Launch**: Open Pupil from Applications, Launchpad, or Spotlight. The Control Center window opens immediately for configuration, and tucks into your menu bar when closed.

> [!TIP]
> If macOS Gatekeeper blocks opening on first launch because the app was downloaded without an Apple Developer ID notarization certificate, run:
> ```bash
> xattr -cr /Applications/Pupil.app
> ```
> Or Right-Click `Pupil.app` in `/Applications` $\rightarrow$ Open $\rightarrow$ Confirm "Open".

---

## Building & Running

### Requirements
* macOS 15.0 (Sequoia) or later
* Swift 6.0+

### Quick Start

```bash
# 1. Run unit test suite
swift test

# 2. Package single downloadable installer (Pupil.dmg + Pupil.zip)
./scripts/build-dmg.sh

# 3. Launch menu bar sentinel or reveal Settings
open "./dist/Pupil.app"
./dist/Pupil.app/Contents/MacOS/Pupil --open-settings
```

---

## Repository Structure

```
Pupil/
├── Package.swift
├── scripts/
│   └── bundle-app.sh
├── Sources/Pupil/
│   ├── PupilApp.swift                  # @main App, AppDelegate, NSStatusItem menu bar
│   ├── Core/
│   │   ├── SecurityCoordinator.swift   # State machine: DISARMED -> ARMING -> ARMED -> TAMPER -> ALARM
│   │   ├── PowerAndLidMonitor.swift    # IOKit AC charger, AppleClamshellState & IOPMAssertion
│   │   ├── LockMonitor.swift           # DistributedNotificationCenter lock/sleep/wake monitor
│   │   ├── SirenSynthesizer.swift      # Zero-asset AVAudioEngine dual-tone alarm synthesizer
│   │   └── KeychainManager.swift       # Salted SHA-256 Keychain PIN & Touch ID authentication
│   ├── Vision/
│   │   ├── CameraManager.swift         # AVFoundation 10 FPS capture session
│   │   ├── VisionGazeDetector.swift    # Apple Vision landmarks & GazeTemporalAggregator
│   │   └── VisionMotionDetector.swift  # Apple Vision upper-background registration & lift sentry
│   ├── NotchOverlay/
│   │   ├── NotchGeometry.swift         # Hardware notch & Dynamic Island pill dimensions
│   │   ├── NotchShape.swift            # Concave top-flare notch silhouette path
│   │   ├── NotchWindow.swift           # Shielding-level borderless NSPanel
│   │   ├── NotchOverlayView.swift      # Tracking PupilEyeVectorView & inline disarm UI
│   │   └── NotchOverlayController.swift# Multi-display notch window lifecycle
│   └── Settings/
│       ├── PupilSettings.swift         # Observable UserDefaults preferences store
│       ├── SettingsMetrics.swift       # Adaptive colors, typography & spacing tokens
│       ├── SettingsControls.swift      # VisualEffectView, WindowConfigurator, SettingsGroup
│       ├── SettingsTab.swift           # General, Gaze, Sensors, Alarm, About tabs
│       ├── SettingsTabBar.swift        # Floating capsule tab bar with unfurling labels
│       ├── ProgressiveHeaderBlur.swift # Layered material gradient header blur
│       ├── HeaderStatusButton.swift    # Live security status & disarm popover pill
│       ├── SettingsWindowView.swift    # Root settings scene with trackpad swipe support
│       └── Pages/
│           ├── GeneralSettingsPage.swift
│           ├── GazeSettingsPage.swift
│           ├── SensorsSettingsPage.swift
│           ├── AlarmSettingsPage.swift
│           └── AboutSettingsPage.swift
└── Tests/PupilTests/
    └── PupilSecurityTests.swift
```

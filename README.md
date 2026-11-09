<h1 align="center">
  <br>
  Pupil
  <br>
</h1>

<h3 align="center">Native macOS menu bar & notch security sentinel for solo study sessions</h3>

<p align="center">
  <a href="#license"><img src="https://img.shields.io/badge/license-MIT-black.svg" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black.svg" alt="macOS 14+">
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

Just like [Glance](https://github.com/jonnyoo/glance), Pupil is packaged into a single standalone drag-and-drop macOS disk image (`Pupil.dmg`):

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
pupil/
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

---

## Vibe Coding & Architectural Safety Audit Checklist

This project adheres strictly to the **Vibe Coding & Architectural Safety Audit Checklist**, ensuring that rapid agentic iterations maintain rigorous defense-in-depth, strict typing, and zero architectural shortcuts:

### 1. Architectural & Integration Mandates
- [x] **Resilient Integrations**: Built exclusively on official native Apple frameworks (`IOKit`, `Vision`, `AVFoundation`, `LocalAuthentication`, `Security`, `AppKit`, `SwiftUI`). Zero fragile DOM scraping, webviews, or private runtime hacks.
- [x] **Authentication Security**: Zero plaintext PINs, passwords, or tokens in logs, code, or storage. Disarm PINs are salted and SHA-256 hashed in the native macOS Keychain (`Security` framework).
- [x] **MFA / Biometric Integrity**: Native Touch ID integration via Apple Secure Enclave (`LocalAuthentication` framework). Biometric checks cannot be bypassed programmatically or mocked in release builds.
- [x] **Strict Typing & Concurrency**: 100% strict Swift 6 concurrency compliance across the entire codebase. Zero data races, zero compiler warnings, and strict `@MainActor` thread-safety on all UI controllers.

### 2. Vibe Coding & Agentic Safety
- [x] **Untrusted by Default**: The application never relies on external LLM outputs or untrusted network models for security-critical decisions (authorization, tamper thresholds, disarm validation).
- [x] **Subsystem Validation**: All user inputs (PIN codes, exit delays, grace periods, camera ROIs) are strictly bounded and validated by strong domain types (`PupilSettings`, `KeychainManager`).
- [x] **Zero Custom Auth Hacks**: No homemade session cookies, ad-hoc token stores, or custom cryptography. Relies strictly on Apple's hardened Keychain Services and Secure Enclave hardware.
- [x] **Least Privilege**: Runs as an unprivileged macOS user-space agent (`LSUIElement = true`). Requires no `root`, `sudo`, or kernel extensions.
- [x] **No Secret Leakage**: Zero API keys, telemetry endpoints, or private tokens in source code, release bundles, or commits. `.env` and local credentials are strictly excluded via `.gitignore`.
- [x] **Cost, Thermal & Loop Controls**:
  - Camera capture is strictly throttled to 10 FPS with transient in-memory frame processing to prevent thermal throttling or excessive battery consumption.
  - Sleep-prevention assertions (`IOPMAssertion`) automatically disarm and release upon disarming, alarm timeout, or exit delay cancellation.
  - All timers and deterrent dismissals use bounded `DispatchWorkItem` handles to eliminate infinite prompt loops.

### 3. Baseline Stack & Workflow
- [x] **100% On-Device Privacy**: Video frames and Apple Vision landmarks remain strictly transient in system memory. Zero frames, face crops, or metrics are ever written to disk or transmitted across networks.
- [x] **Aggressive Deadbands & Noise Rejection**: Spatial lift detection utilizes upper-background homography warp and translation norms to suppress ambient $< 0.5\text{s}$ desk vibrations while promptly escalating continuous displacement.
- [x] **Idempotent Operations**: Arming, disarming, and state transitions are strictly idempotent, preventing duplicate events or race conditions during rapid retries.
- [x] **Mocked & Isolated Testing**: Unit test suite (`PupilSecurityTests.swift`) executes in isolated `UserDefaults` suites without touching production settings or requiring live hardware.

---

## Security & Privacy Disclaimers

> [!IMPORTANT]
> **Educational & Deterrence Tool Only**: Pupil is designed and distributed solely as a software-based anti-theft and anti-shoulder-surfing deterrent. It is **not** an unbreakable physical lock, an insurance policy, or a substitute for personal vigilance. Never leave laptops or sensitive personal property unattended in unmonitored or high-risk public spaces.

> [!WARNING]
> **Hardware & Power Boundaries**: Software sentinels depend entirely on the host operating system remaining powered and running. If a device's battery completely depletes, or if an adversary forcibly holds down the hardware power button for 10 seconds to induce a hardware cold-poweroff, software monitoring will terminate. Users should enable **macOS FileVault full-disk encryption** and a firmware password to ensure data-at-rest protection.

> [!NOTE]
> **Physical Theft Limitation**: Pupil utilizes audible dual-tone sirens, visual Dynamic Island badges, and high-opacity frosted screen privacy shields to deter opportunists. It cannot physically tether hardware to a table or physically stop an individual who chooses to grab hardware despite an active siren.

---

## Acknowledgments & Credits

* **[Glance (`jonnyoo/glance`)](https://github.com/jonnyoo/glance)** by **Jonathan Zhou** — Pupil's native macOS Settings window architecture (`.sidebar` vibrancy, unified toolbar chrome, progressive header blur, floating bottom capsule tab bar with trackpad swipe navigation, and custom settings controls) and hardware notch geometry patterns are adapted from Glance under the MIT License.

---

## License

Pupil is licensed under the **MIT License**.

```
MIT License

Copyright (c) 2026 Steve Wong
Portions of the macOS Settings UI, window chrome, and notch geometry are adapted from Glance (https://github.com/jonnyoo/glance), Copyright (c) 2026 Jonathan Zhou.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

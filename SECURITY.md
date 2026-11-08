# Security Policy & Architecture

## Overview

**Pupil** is designed as a native, lightweight, on-device macOS security sentinel for students and solo workers in libraries, cafes, and open workspaces. It deters opportunistic theft and shoulder-surfing through real-time sensors, hardware notch indicators, screen privacy shields, and audio-visual deterrents.

---

## Threat Model & Security Scope

### 1. In-Scope Threats (Deterred)
* **Shoulder Surfing / Screen Snooping**: Unauthorized individuals glancing or looking at your display in public spaces. Mitigated by on-device Apple Vision iris tracking and instant high-opacity frosted obsidian screen privacy blurring.
* **Unauthorized Input / Snooping While Armed**: An unauthorized person attempting to type or click on your machine while you step away. Mitigated by global and local event sentries that immediately lock the screen behind a shielding panel and challenge for PIN or Touch ID.
* **Charger Unplugging**: A thief disconnecting your MagSafe or USB-C charging cable. Detected instantaneously via `IOPSCopyPowerSourcesInfo` to trigger the tamper grace countdown.
* **Grab & Walk on Battery**: A thief picking up an open laptop while running on battery power. Mitigated by Apple Vision upper-background spatial registration ($> 1.2\text{s}$ continuous displacement or camera occlusion).
* **Clamshell Snatch**: A thief closing the lid to quickly shove the laptop into a backpack. Intercepted via `AppleClamshellState` with `IOPMAssertionCreateWithName` sleep-prevention assertions to synthesize a maximum-volume dual-tone siren before macOS cuts audio.

### 2. Out-of-Scope Threats (Non-Mitigated)
* **Mechanical / Brute-Force Physical Theft**: Pupil is a software-based deterrent; it cannot physically tether a device to a desk or withstand a motivated thief who ignores an active audible alarm and flees.
* **Hardware Forensic Extraction**: If an adversary obtains permanent physical custody of an unencrypted device, software-layer sentinels cannot prevent offline hardware analysis. Users must maintain FileVault disk encryption.
* **Complete Battery Exhaustion / Cold Force-Off**: Holding down the hardware power button for 10 seconds or allowing the battery to completely deplete to 0% powers off the Mac hardware at the firmware level, terminating all running operating system processes.

---

## Vibe Coding & Agentic Safety Audit Checklist

This codebase has been verified against the **Vibe Coding & Architectural Safety Audit Checklist**:

### 1. Architectural & Integration Mandates
- [x] **Resilient Integrations**: 100% native Apple SDKs (`IOKit`, `Vision`, `AVFoundation`, `LocalAuthentication`, `Security`). Zero brittle scraping, zero webview shims, zero unofficial private APIs.
- [x] **Authentication Security**: Zero plaintext PINs or credentials stored in memory, logs, or filesystem. All credentials use cryptographically secure salts and SHA-256 hashes stored directly in the macOS Keychain (`kSecClassGenericPassword`).
- [x] **MFA / Biometric Security Boundaries**: Authenticates through native Apple Secure Enclave Touch ID via `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`. No bypasses, mock overrides in production, or programmatic gates.
- [x] **Strict Typing & Compiler Verification**: Built in strict Swift 6 concurrency mode with zero compiler type errors, zero data races, and strict `@MainActor` thread confinement on UI controllers.

### 2. Vibe Coding & Agentic Safety
- [x] **Untrusted by Default**: Zero reliance on external LLMs or third-party web endpoints for authorization, state transitions, or credential validation.
- [x] **Subsystem Validation**: All user-configurable parameters (exit delays, grace periods, siren frequencies, camera ROIs) are strictly bounded to finite enum stops and sanitized models (`PupilSettings`).
- [x] **Zero Custom Auth Hacks**: Does not invent proprietary encryption or roll custom session schemes; delegates entirely to macOS Keychain Services and Secure Enclave hardware.
- [x] **Least Privilege**: Runs strictly as an unprivileged user-space agent (`LSUIElement = true`). Requires no `sudo`, `root` privileges, kernel extensions, or system file modifications.
- [x] **No Secret Leakage**: Zero API keys, tracking tokens, telemetry beacons, or network credentials embedded in source code or git commits. `.env` and local secrets are excluded via `.gitignore`.
- [x] **Resource & Loop Controls**:
  - Vision camera capture is throttled to 10 FPS with transient in-memory frame buffers to prevent thermal throttling or excessive battery drain.
  - Sleep assertions acquire a strictly scoped `IOPMAssertion` that is released upon disarm or alarm timeout.
  - Gaze and tamper dismissal timers use bounded `DispatchWorkItem` tokens to prevent runaway timer loops.

### 3. Baseline Stack & Workflow Compliance
- [x] **Pure Native Stack**: Swift 6, SwiftUI, AppKit, CoreGraphics, AVFoundation, and Apple Vision. Zero Electron, zero Node.js, zero third-party package dependencies.
- [x] **Aggressive Caching & Deadbands**: Spatial registration uses structural image homography and Frobenius norm deadbands to filter ambient desk vibrations ($< 0.5\text{s}$) before triggering alerts.
- [x] **Idempotent Operations**: Disarming, arming, and state-machine transitions are idempotent. Retries or duplicate events do not cause inconsistent states.
- [x] **Mocked & Isolated Testing**: Full unit test suite (`PupilSecurityTests.swift`) runs in complete isolation using ephemeral `UserDefaults(suiteName:)` instances, verifying all transitions with zero external side effects.

---

## Security & Privacy Disclaimers

### 1. Educational & Deterrence Tool Only
> [!IMPORTANT]
> **Pupil is provided solely as an open-source theft-deterrence utility.** It is not an insurance policy, an unbreakable hardware lock, or a substitute for personal vigilance. Never leave valuable personal property unattended in unmonitored or high-risk public environments.

### 2. "AS IS" Limitation of Warranty & Liability
Pupil is distributed under the **MIT License**. The software is provided **"AS IS"**, without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and non-infringement. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability—including but not limited to laptop theft, hardware loss, data loss, or incidental damages—arising from the use or inability to use this software.

### 3. Reporting a Vulnerability
If you discover a security vulnerability or potential privacy leak in Pupil:
1. Please do **NOT** open a public GitHub issue.
2. Email a detailed description and reproduction steps directly to **Steve Wong** via GitHub or security contact.
3. Include your macOS version, hardware architecture (e.g., Apple Silicon M1/M2/M3/M4), and steps to reproduce.

//
//  ScreenShieldView.swift
//  Pupil
//
//  SwiftUI content rendered in ScreenShieldWindow:
//  Full-screen native AppKit visual effect blur with a subtle privacy vignette.
//  When anything is clicked, opens a clean macOS authentication dialog in the center of the screen.
//

import AppKit
import SwiftUI

public struct ScreenShieldView: View {
    @Bindable var coordinator: SecurityCoordinator
    public var isPrimary: Bool = true
    @State private var isPromptPresented: Bool = true
    @State private var pinInput = ""
    @State private var hasError = false
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var isPinFocused: Bool

    public init(coordinator: SecurityCoordinator, isPrimary: Bool = true) {
        self.coordinator = coordinator
        self.isPrimary = isPrimary
    }

    private var isAlarm: Bool { coordinator.state == .alarm }
    private var isTamper: Bool { coordinator.state == .tamperPending }
    private var isGazePrivacyOnly: Bool {
        coordinator.state == .armed &&
        !coordinator.settings.blurBackgroundWhenArmed &&
        !coordinator.isInteractiveUnlockRequested &&
        coordinator.isGazeWarningActive &&
        coordinator.settings.blurScreenOnGaze
    }

    public var body: some View {
        ZStack {
            // 1. Deep frosted privacy scrim: high-opacity obsidian base that completely blocks screen snooping
            Color(red: 0.06, green: 0.07, blue: 0.09).opacity(0.95)
                .ignoresSafeArea()

            // 2. Native frosted glass material layer for macOS vibrancy and glass depth
            VisualEffectView(material: .fullScreenUI, blendingMode: .withinWindow, state: .active)
                .ignoresSafeArea()
                .opacity(0.85)

            // 3. Deep radial privacy vignette
            RadialGradient(
                colors: [
                    Color.black.opacity(0.35),
                    Color.black.opacity(0.82)
                ],
                center: .center,
                startRadius: 180,
                endRadius: 900
            )
            .ignoresSafeArea()

            // 4. Click layer: clicking background refocuses the PIN prompt or triggers interactive unlock
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    if coordinator.state == .armed && !coordinator.isInteractiveUnlockRequested {
                        coordinator.handleArmedUserInput()
                    } else if isPrimary {
                        isPinFocused = true
                    } else {
                        NotificationCenter.default.post(name: .screenShieldFocusPrimary, object: nil)
                    }
                }

            // 5. Centered modal dialog or transient gaze privacy capsule
            if isPrimary && isPromptPresented {
                if isGazePrivacyOnly {
                    gazePrivacyCapsule
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                } else {
                    macOSPasswordWindow
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            )
                        )
                        .offset(x: shakeOffset)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if isPrimary {
                isPromptPresented = true
                openPrompt()
            }
        }
        .onChange(of: coordinator.state) { _, _ in
            if isPrimary {
                openPrompt()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .screenShieldOpenPrompt)) { _ in
            if isPrimary {
                openPrompt()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .screenShieldDismissPrompt)) { _ in
            if isPrimary {
                handleDismissOrCancel()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .screenShieldDeleteKey)) { _ in
            if isPrimary && !pinInput.isEmpty {
                pinInput.removeLast()
                hasError = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .screenShieldSubmitPrompt)) { _ in
            if isPrimary {
                submitPin()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .screenShieldDigitTyped)) { notif in
            if isPrimary, let digit = notif.object as? String, pinInput.count < 8 {
                pinInput.append(digit)
                hasError = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .screenShieldInputDetected)) { _ in
            if coordinator.state == .armed && !coordinator.isInteractiveUnlockRequested {
                coordinator.handleArmedUserInput()
            }
        }
        .onChange(of: coordinator.isInteractiveUnlockRequested) { _, requested in
            if requested && isPrimary {
                openPrompt()
            }
        }
    }

    // MARK: - Small macOS Authentication Window & Gaze Privacy Capsule

    private var gazePrivacyCapsule: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PupilTheme.warningAmber.opacity(0.12))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle().strokeBorder(PupilTheme.warningAmber.opacity(0.35), lineWidth: 1)
                    )

                PupilEyeVectorView(
                    isOpen: true,
                    lookOffset: coordinator.eyeLookOffset,
                    accentColor: PupilTheme.warningAmber,
                    size: 26
                )
            }

            VStack(spacing: 4) {
                Text("Privacy Shield Active")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)

                Text("Screen obscured while gaze is detected.\nLook away to dismiss, or press any key / click to unlock.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 270)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.11).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.55), radius: 32, x: 0, y: 14)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var macOSPasswordWindow: some View {
        VStack(spacing: 16) {
            lockBadgeView
            titleSubtitleView
            pinInputField
            actionButtonsView
        }
        .padding(22)
        .frame(width: 288)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.11).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.55), radius: 32, x: 0, y: 14)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var lockBadgeView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: 52, height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )

            if isAlarm {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(PupilTheme.alarmRed)
            } else if isTamper {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(PupilTheme.warningAmber)
            } else {
                PupilEyeVectorView(
                    isOpen: true,
                    lookOffset: coordinator.eyeLookOffset,
                    accentColor: Color.white.opacity(0.92),
                    size: 28
                )
            }
        }
        .padding(.top, 4)
    }

    private var titleSubtitleView: some View {
        VStack(spacing: 4) {
            Text(windowTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)

            Text(windowSubtitle)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
    }

    private var pinInputField: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                SecureField("Enter PIN", text: $pinInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .focused($isPinFocused)
                    .onSubmit {
                        submitPin()
                    }

                if !pinInput.isEmpty {
                    Button {
                        if !pinInput.isEmpty {
                            pinInput.removeLast()
                            hasError = false
                        }
                    } label: {
                        Image(systemName: "delete.backward.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .help("Delete last digit")
                }

                if coordinator.settings.allowTouchIDDisarm {
                    Button {
                        Task {
                            _ = await coordinator.disarmWithTouchID()
                        }
                    } label: {
                        Image(systemName: "touchid")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.80))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Unlock with Touch ID")
                }

                Button(action: submitPin) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(pinInput.isEmpty ? Color.white.opacity(0.28) : Color.white.opacity(0.90))
                }
                .buttonStyle(.plain)
                .disabled(pinInput.isEmpty)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.42))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        hasError ? PupilTheme.alarmRed : (isPinFocused ? Color.white.opacity(0.36) : Color.white.opacity(0.14)),
                        lineWidth: 1
                    )
            )

            if hasError {
                Text("Incorrect PIN")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PupilTheme.alarmRed)
                    .transition(.opacity)
            }
        }
    }

    private var actionButtonsView: some View {
        HStack(spacing: 10) {
            if coordinator.isShieldPreviewActive || coordinator.state == .arming {
                Button(action: handleDismissOrCancel) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }

            Button(action: submitPin) {
                Text("Unlock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.white)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Status Copy

    private var windowTitle: String {
        switch coordinator.state {
        case .disarmed:
            return "Pupil Preview"
        case .arming:
            return "Arming (\(coordinator.countdownSecondsRemaining)s)"
        case .armed:
            return "Pupil is locked"
        case .tamperPending:
            return "Tamper detected — \(coordinator.countdownSecondsRemaining)s"
        case .alarm:
            return "Alarm active"
        }
    }

    private var windowSubtitle: String {
        switch coordinator.state {
        case .disarmed:
            return "Press Esc or click Cancel to close preview."
        case .arming:
            return "Enter your PIN or click Cancel to stop."
        case .armed:
            return "Enter your PIN or use Touch ID to unlock."
        case .tamperPending:
            return "Enter your PIN to cancel the alarm."
        case .alarm:
            return "Enter your PIN to silence the alarm."
        }
    }

    // MARK: - Actions

    private func handleDismissOrCancel() {
        if isGazePrivacyOnly {
            coordinator.dismissGazeWarning()
        } else if coordinator.isShieldPreviewActive {
            coordinator.previewScreenShield(durationSeconds: 0)
        } else if coordinator.state == .arming {
            coordinator.cancelArmingDuringExitDelay()
        } else if !pinInput.isEmpty {
            pinInput = ""
            hasError = false
        }
    }

    private func openPrompt() {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
            isPromptPresented = true
            hasError = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isPinFocused = true
        }
        if coordinator.settings.allowTouchIDDisarm && !isGazePrivacyOnly {
            Task {
                _ = await coordinator.disarmWithTouchID()
            }
        }
    }

    private func closePrompt() {
        handleDismissOrCancel()
    }

    private func submitPin() {
        guard !pinInput.isEmpty else {
            isPinFocused = true
            return
        }
        let success = coordinator.disarmWithPin(pinInput)
        pinInput = ""
        if success {
            hasError = false
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                isPromptPresented = false
            }
        } else {
            hasError = true
            triggerErrorShake()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPinFocused = true
            }
        }
    }

    private func triggerErrorShake() {
        withAnimation(.default) { shakeOffset = -9 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(.default) { shakeOffset = 9 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.default) { shakeOffset = -5 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.21) {
            withAnimation(.default) { shakeOffset = 0 }
        }
    }
}

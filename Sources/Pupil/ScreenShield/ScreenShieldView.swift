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
    @State private var isPromptPresented: Bool = false
    @State private var pinInput = ""
    @State private var hasError = false
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var isPinFocused: Bool

    public init(coordinator: SecurityCoordinator) {
        self.coordinator = coordinator
    }

    private var isAlarm: Bool { coordinator.state == .alarm }
    private var isTamper: Bool { coordinator.state == .tamperPending }

    public var body: some View {
        ZStack {
            // 1. Native behind-window frosted glass blur (always active while armed)
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow, state: .active)
                .ignoresSafeArea()

            // 2. Subtle privacy vignette
            RadialGradient(
                colors: [
                    Color.black.opacity(0.32),
                    Color.black.opacity(0.68)
                ],
                center: .center,
                startRadius: 220,
                endRadius: 920
            )
            .ignoresSafeArea()

            // 3. Fullscreen click-capture layer for opening or dismissing the password prompt
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isPromptPresented {
                        openPrompt()
                    } else {
                        closePrompt()
                    }
                }

            // 4. Centered macOS authentication dialog (presented only on interaction)
            if isPromptPresented {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if isAlarm || isTamper {
                openPrompt()
            }
        }
        .onChange(of: coordinator.state) { _, newState in
            if newState == .alarm || newState == .tamperPending {
                openPrompt()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .screenShieldOpenPrompt)) { _ in
            if !isPromptPresented {
                openPrompt()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .screenShieldDismissPrompt)) { _ in
            if isPromptPresented {
                closePrompt()
            }
        }
    }

    // MARK: - Small macOS Authentication Window

    private var macOSPasswordWindow: some View {
        VStack(spacing: 16) {
            // App icon / lock badge
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

            // Title & subtitle
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

            // Password / PIN field
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    SecureField("Enter PIN", text: $pinInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white)
                        .focused($isPinFocused)
                        .onSubmit {
                            submitPin()
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

            // Actions
            HStack(spacing: 10) {
                if !isAlarm && !isTamper {
                    Button(action: closePrompt) {
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
        .onTapGesture { }
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
            return "Press Esc or click Unlock to close preview."
        case .arming:
            return "Enter your PIN to cancel arming."
        case .armed:
            return "Enter your PIN or use Touch ID to unlock."
        case .tamperPending:
            return "Enter your PIN to cancel the alarm."
        case .alarm:
            return "Enter your PIN to silence the alarm."
        }
    }

    // MARK: - Actions

    private func openPrompt() {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
            isPromptPresented = true
            hasError = false
            pinInput = ""
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isPinFocused = true
        }
    }

    private func closePrompt() {
        guard !isAlarm && !isTamper else { return }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
            isPromptPresented = false
            hasError = false
            pinInput = ""
            isPinFocused = false
        }
    }

    private func submitPin() {
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

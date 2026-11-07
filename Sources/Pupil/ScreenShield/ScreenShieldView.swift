//
//  ScreenShieldView.swift
//  Pupil
//
//  SwiftUI content rendered in ScreenShieldWindow:
//  Full-screen native AppKit visual effect blur with an obsidian privacy vignette.
//  When anything is clicked, opens a small native macOS UI window in the center of the screen
//  requesting the password / PIN or Touch ID to unblur.
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

    private var accentColor: Color {
        if isAlarm { return PupilTheme.alarmRed }
        if isTamper { return PupilTheme.warningAmber }
        return Color.white.opacity(0.85)
    }

    private var cardBorderGradient: LinearGradient {
        if isAlarm {
            return LinearGradient(
                colors: [PupilTheme.alarmRed.opacity(0.8), PupilTheme.alarmRed.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        if isTamper {
            return LinearGradient(
                colors: [PupilTheme.warningAmber.opacity(0.8), PupilTheme.warningAmber.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Color.white.opacity(0.22), Color.white.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public var body: some View {
        ZStack {
            // 1. Native behind-window frosted glass blur (always locked and active)
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow, state: .active)
                .ignoresSafeArea()

            // 2. Obsidian privacy vignette darkening background content
            RadialGradient(
                colors: [
                    Color.black.opacity(0.35),
                    Color.black.opacity(0.70)
                ],
                center: .center,
                startRadius: 200,
                endRadius: 900
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

            // 4. Centered small macOS UI password prompt window (presented only on interaction)
            if isPromptPresented {
                macOSPasswordWindow
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.94).combined(with: .opacity),
                            removal: .scale(scale: 0.94).combined(with: .opacity)
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

    // MARK: - Small macOS UI Window

    private var macOSPasswordWindow: some View {
        VStack(spacing: 0) {
            // Top Bar with subtle Close Button
            HStack {
                Spacer()
                if !isAlarm && !isTamper {
                    Button(action: closePrompt) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.60))
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("Close (Esc)")
                }
            }
            .padding(.top, 14)
            .padding(.horizontal, 16)

            // Center Content
            VStack(spacing: 14) {
                // Biometric aperture eye or security glyph
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.14),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle().strokeBorder(cardBorderGradient, lineWidth: 1)
                        )

                    if isAlarm {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(PupilTheme.alarmRed)
                    } else if isTamper {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(PupilTheme.warningAmber)
                    } else {
                        PupilEyeVectorView(
                            isOpen: true,
                            lookOffset: coordinator.eyeLookOffset,
                            accentColor: accentColor,
                            size: 30
                        )
                    }
                }

                // Window Headline & Subtitle
                VStack(spacing: 4) {
                    Text(windowTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isAlarm ? PupilTheme.alarmRed : (isTamper ? PupilTheme.warningAmber : Color.white))

                    Text(windowSubtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 250)
                }

                // Password / PIN Input
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.40))
                            .padding(.leading, 10)

                        SecureField("Password or PIN", text: $pinInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
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
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Color.white.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                            .help("Authenticate with Touch ID")
                            .padding(.trailing, 6)
                        }
                    }
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.50))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                hasError ? PupilTheme.alarmRed : (isPinFocused ? Color.white.opacity(0.40) : Color.white.opacity(0.18)),
                                lineWidth: hasError ? 1.5 : 1
                            )
                    )

                    if hasError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text("Incorrect PIN. Please try again.")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(PupilTheme.alarmRed)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 4)

                // Dialog Action Buttons: Cancel and Unlock
                HStack(spacing: 12) {
                    if !isAlarm && !isTamper {
                        Button(action: closePrompt) {
                            Text("Cancel")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.85))
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.cancelAction)
                    }

                    Button(action: submitPin) {
                        Text(isAlarm ? "Disarm Siren" : "Unlock")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(isAlarm ? PupilTheme.alarmRed : Color.white)
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
        }
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.12).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.24),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.65), radius: 36, x: 0, y: 16)
        )
        // Consume clicks inside the dialog so they don't fall through to the background
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { }
    }

    // MARK: - Status Headlines

    private var windowTitle: String {
        switch coordinator.state {
        case .disarmed:
            return "Screen Shield Preview"
        case .arming:
            return "Arming System (\(coordinator.countdownSecondsRemaining)s)"
        case .armed:
            return "Pupil Locked"
        case .tamperPending:
            return "Tamper Detected (\(coordinator.countdownSecondsRemaining)s)"
        case .alarm:
            return "ALARM TRIGGERED"
        }
    }

    private var windowSubtitle: String {
        switch coordinator.state {
        case .disarmed:
            return "Click Unlock or press Esc to dismiss preview."
        case .arming:
            return "Exit delay in progress. Enter PIN to abort."
        case .armed:
            return "Enter your PIN or password to unlock this Mac."
        case .tamperPending:
            return "Enter PIN immediately to abort siren."
        case .alarm:
            return "Enter Keychain PIN to silence siren and disarm."
        }
    }

    // MARK: - Actions

    private func openPrompt() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
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
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
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
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                isPromptPresented = false
            }
        } else {
            hasError = true
            triggerErrorShake()
        }
    }

    private func triggerErrorShake() {
        withAnimation(.default) {
            shakeOffset = -10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.default) {
                shakeOffset = 10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.default) {
                shakeOffset = -6
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.default) {
                shakeOffset = 0
            }
        }
    }
}

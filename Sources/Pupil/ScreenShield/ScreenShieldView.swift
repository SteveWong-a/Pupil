//
//  ScreenShieldView.swift
//  Pupil
//
//  SwiftUI content rendered in ScreenShieldWindow:
//  Full-screen native AppKit visual effect blur with an obsidian privacy vignette
//  and an Apple-grade biometric security card that cannot be unblurred until disarmed.
//

import AppKit
import SwiftUI

public struct ScreenShieldView: View {
    @Bindable var coordinator: SecurityCoordinator
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
            colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public var body: some View {
        ZStack {
            // Native behind-window frosted glass blur
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                .ignoresSafeArea()

            // Obsidian privacy vignette darkening background content
            RadialGradient(
                colors: [
                    Color.black.opacity(0.35),
                    Color.black.opacity(0.68)
                ],
                center: .center,
                startRadius: 200,
                endRadius: 900
            )
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                isPinFocused = true
                if coordinator.settings.allowTouchIDDisarm {
                    Task {
                        _ = await coordinator.disarmWithTouchID()
                    }
                }
            }

            // Center Biometric Security Card
            centerSecurityCard
                .offset(x: shakeOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isPinFocused = true
        }
    }

    private var centerSecurityCard: some View {
        VStack(spacing: 16) {
            // Biometric aperture eye
            PupilEyeVectorView(
                isOpen: true,
                lookOffset: coordinator.eyeLookOffset,
                accentColor: accentColor,
                size: 54
            )
            .padding(.top, 4)

            // Header titles
            VStack(spacing: 5) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 7, height: 7)
                    Text("PUPIL SCREEN SHIELD")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Color.white)
                }

                Text(statusHeadline)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isAlarm ? PupilTheme.alarmRed : (isTamper ? PupilTheme.warningAmber : Color.white))

                Text("Background is locked & blurred to protect privacy.\nAuthenticate with Keychain PIN or Touch ID to unblur.")
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.60))
                    .frame(maxWidth: 320)
            }

            // Inline PIN and Touch ID disarm controls
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    SecureField("Enter PIN", text: $pinInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white)
                        .focused($isPinFocused)
                        .multilineTextAlignment(.center)
                        .frame(width: 120, height: 32)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .overlay(
                            Capsule().strokeBorder(
                                hasError ? PupilTheme.alarmRed : Color.white.opacity(0.24),
                                lineWidth: hasError ? 1.5 : 1
                            )
                        )
                        .onSubmit {
                            submitPin()
                        }

                    Button(action: submitPin) {
                        Text("Disarm")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(Capsule().fill(Color.white))
                    }
                    .buttonStyle(.plain)

                    if coordinator.settings.allowTouchIDDisarm {
                        Button {
                            Task {
                                _ = await coordinator.disarmWithTouchID()
                            }
                        } label: {
                            Image(systemName: "touchid")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.white.opacity(0.18)))
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help("Disarm with Touch ID")
                    }
                }

                if hasError {
                    Text("Incorrect PIN. Please try again.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PupilTheme.alarmRed)
                        .transition(.opacity)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(cardBorderGradient, lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.60), radius: 30, y: 12)
        )
    }

    private var statusHeadline: String {
        switch coordinator.state {
        case .disarmed:
            return "Screen Shield Preview"
        case .arming:
            return "Arming System (\(coordinator.countdownSecondsRemaining)s)"
        case .armed:
            return "Screen Armed & Protected"
        case .tamperPending:
            return "Tamper Detected: \(coordinator.countdownSecondsRemaining)s to Siren"
        case .alarm:
            return "ALARM LATCHED — DISARM REQUIRED"
        }
    }

    private func submitPin() {
        let success = coordinator.disarmWithPin(pinInput)
        pinInput = ""
        if success {
            hasError = false
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


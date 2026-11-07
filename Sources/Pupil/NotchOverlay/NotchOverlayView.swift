//
//  NotchOverlayView.swift
//  Pupil
//
//  SwiftUI content rendered inside the MacBook Notch / Dynamic Island overlay.
//  Features a sleek Apple-grade biometric aperture that tracks the observer's gaze,
//  with geometry positioned safely BELOW the physical camera island.
//

import SwiftUI

public struct PupilEyeVectorView: View {
    public var isOpen: Bool
    public var lookOffset: CGPoint
    public var accentColor: Color
    public var size: CGFloat

    @State private var scanPulse = false

    public init(
        isOpen: Bool,
        lookOffset: CGPoint = .zero,
        accentColor: Color = Color.white.opacity(0.85),
        size: CGFloat = 48
    ) {
        self.isOpen = isOpen
        self.lookOffset = lookOffset
        self.accentColor = accentColor
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Subtle ambient pulse wave when gaze is active
            if isOpen {
                Circle()
                    .stroke(accentColor.opacity(scanPulse ? 0.0 : 0.35), lineWidth: 1.2)
                    .frame(width: size * (scanPulse ? 1.45 : 0.95), height: size * (scanPulse ? 1.45 : 0.95))
                    .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: scanPulse)
                    .onAppear { scanPulse = true }
            }

            // Outer precision biometric bezel ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
                .frame(width: size, height: size)
                .background(Circle().fill(Color.black.opacity(0.85)))

            // Concentric optical guide ring
            Circle()
                .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
                .frame(width: size * 0.74, height: size * 0.74)

            // Precision 4-axis reticle tick marks (Apple camera / Face ID style)
            ForEach([0.0, 90.0, 180.0, 270.0], id: \.self) { deg in
                Rectangle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 1.0, height: 3.5)
                    .offset(y: -(size * 0.44))
                    .rotationEffect(.degrees(deg))
            }

            if isOpen {
                // Active optical iris & tracking pupil core
                ZStack {
                    // Glowing cyan iris aura
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accentColor.opacity(0.85), accentColor.opacity(0.15)],
                                center: .center,
                                startRadius: 1,
                                endRadius: size * 0.26
                            )
                        )
                        .frame(width: size * 0.48, height: size * 0.48)

                    // Razor-sharp pupil core that tracks the subject in real time
                    Circle()
                        .fill(Color.black)
                        .frame(width: size * 0.22, height: size * 0.22)
                        .overlay(
                            Circle()
                                .fill(accentColor)
                                .frame(width: size * 0.08, height: size * 0.08)
                        )
                }
                .offset(
                    x: max(-size * 0.16, min(size * 0.16, lookOffset.x * (size * 0.16))),
                    y: max(-size * 0.14, min(size * 0.14, lookOffset.y * (size * 0.14)))
                )
                .animation(.spring(response: 0.22, dampingFraction: 0.76), value: lookOffset)
                .transition(.scale.combined(with: .opacity))
            } else {
                // Sleek standby slit (resting sensor)
                Capsule()
                    .fill(Color.white.opacity(0.40))
                    .frame(width: size * 0.40, height: 2.2)
                    .transition(.opacity)
            }
        }
        .frame(width: size * 1.5, height: size * 1.5)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isOpen)
    }
}

public struct NotchOverlayView: View {
    @Bindable var coordinator: SecurityCoordinator
    let geometry: NotchGeometry
    let onRequestInteractive: (Bool) -> Void

    @State private var enteredPin: String = ""
    @State private var shakeTrigger: Int = 0

    public init(
        coordinator: SecurityCoordinator,
        geometry: NotchGeometry,
        onRequestInteractive: @escaping (Bool) -> Void
    ) {
        self.coordinator = coordinator
        self.geometry = geometry
        self.onRequestInteractive = onRequestInteractive
    }

    private var cameraIslandHeight: CGFloat {
        geometry.hardwareNotchHeight
    }

    private var displayMode: OverlayDisplayMode {
        switch coordinator.state {
        case .disarmed:
            return .hidden
        case .arming:
            return .compactArming
        case .armed:
            if coordinator.isGazeWarningActive {
                switch coordinator.settings.notchStyle {
                case .minimalPill: return .minimalGaze
                case .silent: return .hidden
                }
            }
            return .hidden
        case .tamperPending:
            return .expandedTamper
        case .alarm:
            return .expandedAlarm
        }
    }

    private var currentPanelSize: CGSize {
        let flare = NotchGeometry.flareAllowance(topRadius: currentTopRadius, style: geometry.style)
        let notchH = cameraIslandHeight

        switch displayMode {
        case .hidden:
            return CGSize(width: geometry.closedSize.width + flare, height: geometry.closedSize.height)

        case .compactArming:
            let width: CGFloat = max(240, geometry.closedSize.width + 40)
            let height = notchH + 42
            return CGSize(width: width + flare, height: height)

        case .minimalGaze:
            let width: CGFloat = max(230, geometry.closedSize.width + 30)
            let height = notchH + 42
            return CGSize(width: width + flare, height: height)

        case .expandedTamper, .expandedAlarm:
            let width: CGFloat = max(340, geometry.closedSize.width + 100)
            let height = notchH + 168
            return CGSize(width: width + flare, height: height)
        }
    }

    private var currentTopRadius: CGFloat {
        switch displayMode {
        case .hidden: return NotchGeometry.closedTopRadius
        case .compactArming, .minimalGaze: return 12
        case .expandedTamper, .expandedAlarm: return NotchGeometry.openTopRadius
        }
    }

    private var currentBottomRadius: CGFloat {
        switch displayMode {
        case .hidden: return NotchGeometry.closedBottomRadius
        case .compactArming, .minimalGaze: return 20
        case .expandedTamper, .expandedAlarm: return NotchGeometry.openBottomRadius
        }
    }

    public var body: some View {
        ZStack(alignment: .top) {
            if displayMode != .hidden {
                panelContainer
                    .padding(.top, geometry.style == .pill ? NotchGeometry.pillTopGap : 0)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: displayMode)
        .onChange(of: displayMode) { _, newMode in
            let interactive = (newMode == .compactArming || newMode == .expandedTamper || newMode == .expandedAlarm)
            onRequestInteractive(interactive)
            if !interactive {
                enteredPin = ""
            }
        }
    }

    private var panelContainer: some View {
        ZStack(alignment: .top) {
            // Obsidian Notch body
            NotchShape(
                topRadius: currentTopRadius,
                bottomRadius: currentBottomRadius,
                style: geometry.style
            )
            .fill(Color.black)
            .overlay(
                NotchShape(
                    topRadius: currentTopRadius,
                    bottomRadius: currentBottomRadius,
                    style: geometry.style
                )
                .stroke(
                    LinearGradient(
                        colors: [borderTint.opacity(0.95), borderTint.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: Color.black.opacity(0.55), radius: 18, y: 8)

            // Content positioned safely BELOW the camera island
            VStack(spacing: 0) {
                // Transparent spacer matching the hardware camera island depth
                Color.clear
                    .frame(height: cameraIslandHeight)

                // Visible interactive UI in the extended island drop
                panelVisibleContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, NotchGeometry.flareAllowance(topRadius: currentTopRadius, style: geometry.style) / 2 + 14)
        }
        .frame(width: currentPanelSize.width, height: currentPanelSize.height)
    }

    private var borderTint: Color {
        switch displayMode {
        case .expandedAlarm:
            return Color(red: 1.0, green: 0.27, blue: 0.23)
        case .expandedTamper:
            return Color(red: 1.0, green: 0.62, blue: 0.04)
        case .minimalGaze:
            return Color(white: 0.16)
        default:
            return Color(white: 0.14)
        }
    }

    @ViewBuilder
    private var panelVisibleContent: some View {
        switch displayMode {
        case .hidden:
            EmptyView()

        case .compactArming:
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(PupilTheme.warningAmber)
                        .frame(width: 6, height: 6)
                    Text("ARMING")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(Color.white.opacity(0.9))
                    Text("\(coordinator.countdownSecondsRemaining)s")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(PupilTheme.warningAmber)
                }

                Spacer()

                Button {
                    coordinator.cancelArmingDuringExitDelay()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(Color.white.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)

        case .minimalGaze:
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 6, height: 6)

                Text("WATCHING")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Color.white)

                Spacer()

                Text(String(format: "%.0f%% LOCK", coordinator.latestGazeScore * 100))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

        case .expandedTamper, .expandedAlarm:
            let isAlarm = (displayMode == .expandedAlarm)
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: isAlarm ? "light.beacon.max.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isAlarm ? Color.red : Color.orange)

                    Text(isAlarm ? "ALARM LATCHED" : "TAMPER COUNTDOWN: \(coordinator.countdownSecondsRemaining)s")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(Color.white)
                }
                .padding(.top, 4)

                if let src = coordinator.activeTamperSource {
                    Text(src.rawValue)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.65))
                }

                HStack(spacing: 8) {
                    SecureField("PIN", text: $enteredPin)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .frame(width: 90, height: 26)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 1))
                        .onSubmit {
                            submitPin()
                        }

                    Button {
                        submitPin()
                    } label: {
                        Text("Disarm")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 11)
                            .frame(height: 26)
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
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Color.white.opacity(0.16)))
                        }
                        .buttonStyle(.plain)
                        .help("Disarm with Touch ID")
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(.vertical, 6)
        }
    }

    private func submitPin() {
        let ok = coordinator.disarmWithPin(enteredPin)
        enteredPin = ""
        if !ok {
            shakeTrigger += 1
        }
    }
}

private enum OverlayDisplayMode: Equatable {
    case hidden
    case compactArming
    case minimalGaze
    case expandedTamper
    case expandedAlarm
}

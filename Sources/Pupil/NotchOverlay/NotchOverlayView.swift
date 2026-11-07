//
//  NotchOverlayView.swift
//  Pupil
//
//  SwiftUI content rendered inside the MacBook Notch / Dynamic Island pill.
//  Features a custom vector Pupil Eye that tracks the snooper's gaze offset,
//  plus inline PIN / Touch ID disarm during Tamper or Alarm states.
//

import SwiftUI

public struct PupilEyeVectorView: View {
    public var isOpen: Bool
    public var lookOffset: CGPoint
    public var accentColor: Color
    public var size: CGFloat = 46

    public init(
        isOpen: Bool,
        lookOffset: CGPoint = .zero,
        accentColor: Color = Color(red: 0.35, green: 0.68, blue: 1.0),
        size: CGFloat = 46
    ) {
        self.isOpen = isOpen
        self.lookOffset = lookOffset
        self.accentColor = accentColor
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Outer eye sclera silhouette
            Ellipse()
                .fill(Color.white.opacity(isOpen ? 0.14 : 0.05))
                .frame(width: size * 1.38, height: isOpen ? size * 0.84 : 4)
                .overlay(
                    Ellipse()
                        .strokeBorder(Color.white.opacity(isOpen ? 0.55 : 0.30), lineWidth: 1.6)
                )

            if isOpen {
                // Iris + Pupil tracking the subject
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accentColor, accentColor.opacity(0.45)],
                                center: .center,
                                startRadius: 2,
                                endRadius: size * 0.28
                            )
                        )
                        .frame(width: size * 0.52, height: size * 0.52)

                    Circle()
                        .fill(Color.black)
                        .frame(width: size * 0.24, height: size * 0.24)

                    // Specular catchlight
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: size * 0.09, height: size * 0.09)
                        .offset(x: -size * 0.07, y: -size * 0.07)
                }
                .offset(
                    x: lookOffset.x * (size * 0.20),
                    y: lookOffset.y * (size * 0.10)
                )
                .animation(.spring(response: 0.25, dampingFraction: 0.78), value: lookOffset)
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.75), value: isOpen)
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

    private var displayMode: OverlayDisplayMode {
        switch coordinator.state {
        case .disarmed:
            return .hidden
        case .arming:
            return .compactArming
        case .armed:
            if coordinator.isGazeWarningActive {
                switch coordinator.settings.notchStyle {
                case .expandWithEye: return .expandedGaze
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
        switch displayMode {
        case .hidden:
            return CGSize(width: geometry.closedSize.width + flare, height: geometry.closedSize.height)
        case .compactArming, .minimalGaze:
            if geometry.style == .notch {
                return CGSize(
                    width: geometry.closedSize.width + NotchGeometry.minimalFlankWidth * 2 + flare,
                    height: max(geometry.closedSize.height + 6, 36)
                )
            } else {
                return CGSize(
                    width: NotchGeometry.minimalPillOpenWidth,
                    height: NotchGeometry.minimalPillOpenHeight
                )
            }
        case .expandedGaze:
            let base = geometry.style == .notch ? NotchGeometry.notchOpenSize : NotchGeometry.pillOpenSize
            return CGSize(width: base.width + flare, height: base.height)
        case .expandedTamper, .expandedAlarm:
            let base = geometry.style == .notch ? NotchGeometry.notchOpenSize : NotchGeometry.pillOpenSize
            return CGSize(width: base.width + 28 + flare, height: base.height + 18)
        }
    }

    private var currentTopRadius: CGFloat {
        switch displayMode {
        case .hidden: return NotchGeometry.closedTopRadius
        case .compactArming, .minimalGaze: return 12
        case .expandedGaze, .expandedTamper, .expandedAlarm: return NotchGeometry.openTopRadius
        }
    }

    private var currentBottomRadius: CGFloat {
        switch displayMode {
        case .hidden: return NotchGeometry.closedBottomRadius
        case .compactArming, .minimalGaze: return 18
        case .expandedGaze, .expandedTamper, .expandedAlarm: return NotchGeometry.openBottomRadius
        }
    }

    public var body: some View {
        ZStack(alignment: .top) {
            if displayMode != .hidden {
                panelContainer
                    .padding(.top, geometry.style == .pill ? NotchGeometry.pillTopGap : 0)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.42, dampingFraction: 0.76), value: displayMode)
        .onChange(of: displayMode) { _, newMode in
            let interactive = (newMode == .compactArming || newMode == .expandedTamper || newMode == .expandedAlarm)
            onRequestInteractive(interactive)
            if !interactive {
                enteredPin = ""
            }
        }
    }

    private var panelContainer: some View {
        ZStack {
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
                .stroke(borderTint, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 14, y: 6)

            panelInnerContent
                .padding(.horizontal, NotchGeometry.flareAllowance(topRadius: currentTopRadius, style: geometry.style) / 2 + 14)
        }
        .frame(width: currentPanelSize.width, height: currentPanelSize.height)
    }

    private var borderTint: Color {
        switch displayMode {
        case .expandedAlarm:
            return Color.red.opacity(0.65)
        case .expandedTamper:
            return Color.orange.opacity(0.55)
        case .expandedGaze, .minimalGaze:
            return Color.cyan.opacity(0.38)
        default:
            return Color.white.opacity(0.14)
        }
    }

    @ViewBuilder
    private var panelInnerContent: some View {
        switch displayMode {
        case .hidden:
            EmptyView()
        case .compactArming:
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text("\(coordinator.countdownSecondsRemaining)s")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button {
                    coordinator.cancelArmingDuringExitDelay()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }
        case .minimalGaze:
            HStack {
                Image(systemName: "eye.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.cyan)
                Spacer()
                Text("Watching")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        case .expandedGaze:
            VStack(spacing: 10) {
                Spacer(minLength: geometry.style == .notch ? 22 : 10)
                PupilEyeVectorView(
                    isOpen: true,
                    lookOffset: coordinator.eyeLookOffset,
                    accentColor: .cyan,
                    size: 48
                )
                VStack(spacing: 3) {
                    Text("Pupil Active — Gaze Detected")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("On-device iris tracking active · Zero frames stored")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                }
                ProgressView(value: max(0.15, coordinator.gazeDwellProgress))
                    .tint(.cyan)
                    .frame(width: 160)
                    .padding(.bottom, 10)
            }
        case .expandedTamper, .expandedAlarm:
            let isAlarm = (displayMode == .expandedAlarm)
            VStack(spacing: 10) {
                Spacer(minLength: geometry.style == .notch ? 24 : 10)
                HStack(spacing: 8) {
                    Image(systemName: isAlarm ? "light.beacon.max.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isAlarm ? .red : .orange)
                    Text(isAlarm ? "ALARM LATCHED" : "Tamper Countdown: \(coordinator.countdownSecondsRemaining)s")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                if let src = coordinator.activeTamperSource {
                    Text(src.rawValue)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))
                }

                HStack(spacing: 8) {
                    SecureField("PIN", text: $enteredPin)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(width: 90, height: 26)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                        .onSubmit {
                            submitPin()
                        }

                    Button {
                        submitPin()
                    } label: {
                        Text("Disarm")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.black)
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
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Color.white.opacity(0.16)))
                        }
                        .buttonStyle(.plain)
                        .help("Disarm with Touch ID")
                    }
                }
                .padding(.bottom, 10)
            }
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
    case expandedGaze
    case expandedTamper
    case expandedAlarm
}

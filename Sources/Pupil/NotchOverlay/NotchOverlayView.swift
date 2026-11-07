//
//  NotchOverlayView.swift
//  Pupil
//
//  SwiftUI content rendered inside the MacBook Notch / Dynamic Island overlay.
//  Models Glance's MinimalUnlockView flanking-wing geometry for compact states
//  and clean rounded-stroke viewfinder + eye iconography.
//

import SwiftUI

/// Clean, single-weight rounded-stroke viewfinder + eye glyph matching the Pupil app icon.
public struct PupilEyeVectorView: View {
    public var isOpen: Bool
    public var lookOffset: CGPoint
    public var accentColor: Color
    public var size: CGFloat

    public init(
        isOpen: Bool,
        lookOffset: CGPoint = .zero,
        accentColor: Color = Color.white.opacity(0.92),
        size: CGFloat = 24
    ) {
        self.isOpen = isOpen
        self.lookOffset = lookOffset
        self.accentColor = accentColor
        self.size = size
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            let cx = canvasSize.width / 2
            let cy = canvasSize.height / 2
            let strokeW = max(1.4, s * 0.085)

            // 1. Four rounded corner viewfinder brackets
            let halfSpan = s * 0.40
            let cornerR = s * 0.12
            let armLen = s * 0.14
            let bracketStyle = StrokeStyle(lineWidth: strokeW, lineCap: .round, lineJoin: .round)

            let corners: [(CGFloat, CGFloat)] = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
            for (sx, sy) in corners {
                var path = Path()
                let xCorner = cx + sx * halfSpan
                let yCorner = cy + sy * halfSpan
                let xArmEnd = xCorner - sx * (cornerR + armLen)
                let yArmEnd = yCorner - sy * (cornerR + armLen)
                let xArcStart = xCorner - sx * cornerR
                let yArcEnd = yCorner - sy * cornerR

                path.move(to: CGPoint(x: xArmEnd, y: yCorner))
                path.addLine(to: CGPoint(x: xArcStart, y: yCorner))
                path.addQuadCurve(
                    to: CGPoint(x: xCorner, y: yArcEnd),
                    control: CGPoint(x: xCorner, y: yCorner)
                )
                path.addLine(to: CGPoint(x: xCorner, y: yArmEnd))
                context.stroke(path, with: .color(accentColor.opacity(0.88)), style: bracketStyle)
            }

            // 2. Eye contour + tracking pupil
            if isOpen {
                let eyeRx = s * 0.23
                let eyeRy = s * 0.135
                var eyePath = Path()
                eyePath.move(to: CGPoint(x: cx - eyeRx, y: cy))
                eyePath.addQuadCurve(
                    to: CGPoint(x: cx + eyeRx, y: cy),
                    control: CGPoint(x: cx, y: cy - eyeRy * 1.45)
                )
                eyePath.addQuadCurve(
                    to: CGPoint(x: cx - eyeRx, y: cy),
                    control: CGPoint(x: cx, y: cy + eyeRy * 1.45)
                )
                eyePath.closeSubpath()
                context.stroke(eyePath, with: .color(accentColor), style: bracketStyle)

                let maxShiftX = s * 0.065
                let maxShiftY = s * 0.045
                let px = cx + max(-maxShiftX, min(maxShiftX, lookOffset.x * maxShiftX))
                let py = cy + max(-maxShiftY, min(maxShiftY, lookOffset.y * maxShiftY))
                let pupilR = s * 0.068
                let pupilRect = CGRect(x: px - pupilR, y: py - pupilR, width: pupilR * 2, height: pupilR * 2)
                context.fill(Path(ellipseIn: pupilRect), with: .color(accentColor))
            } else {
                let eyeRx = s * 0.21
                var closedPath = Path()
                closedPath.move(to: CGPoint(x: cx - eyeRx, y: cy))
                closedPath.addQuadCurve(
                    to: CGPoint(x: cx + eyeRx, y: cy),
                    control: CGPoint(x: cx, y: cy + s * 0.08)
                )
                context.stroke(closedPath, with: .color(accentColor.opacity(0.65)), style: bracketStyle)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isOpen)
        .animation(.spring(response: 0.20, dampingFraction: 0.78), value: lookOffset)
    }
}

public struct NotchOverlayView: View {
    @Bindable var coordinator: SecurityCoordinator
    let geometry: NotchGeometry
    let onRequestInteractive: (Bool, CGSize) -> Void

    @State private var enteredPin: String = ""
    @State private var shakeTrigger: Int = 0

    private static let minimalSideWidth: CGFloat = 46
    private static let minimalExtraHeight: CGFloat = 12
    private static let minimalBottomRadius: CGFloat = 14
    private static let pillOpenSize = CGSize(width: 164, height: 38)

    public init(
        coordinator: SecurityCoordinator,
        geometry: NotchGeometry,
        onRequestInteractive: @escaping (Bool, CGSize) -> Void
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

    private var isMinimalWingMode: Bool {
        displayMode == .compactArming || displayMode == .minimalGaze
    }

    private var currentPanelSize: CGSize {
        let flare = NotchGeometry.flareAllowance(topRadius: currentTopRadius, style: geometry.style)
        let notchH = cameraIslandHeight

        switch displayMode {
        case .hidden:
            return CGSize(width: geometry.closedSize.width + flare, height: geometry.closedSize.height)

        case .compactArming, .minimalGaze:
            if geometry.style == .pill {
                return Self.pillOpenSize
            }
            return CGSize(
                width: geometry.closedSize.width + Self.minimalSideWidth * 2 + flare,
                height: geometry.closedSize.height + Self.minimalExtraHeight
            )

        case .expandedTamper, .expandedAlarm:
            let width: CGFloat = max(320, geometry.closedSize.width + 96)
            let height = notchH + 148
            return CGSize(width: width + flare, height: height)
        }
    }

    private var currentTopRadius: CGFloat {
        switch displayMode {
        case .hidden:
            return NotchGeometry.closedTopRadius
        case .compactArming, .minimalGaze:
            return geometry.style == .pill ? Self.pillOpenSize.height / 2 : NotchGeometry.closedTopRadius
        case .expandedTamper, .expandedAlarm:
            return NotchGeometry.openTopRadius
        }
    }

    private var currentBottomRadius: CGFloat {
        switch displayMode {
        case .hidden:
            return NotchGeometry.closedBottomRadius
        case .compactArming, .minimalGaze:
            return geometry.style == .pill ? Self.pillOpenSize.height / 2 : Self.minimalBottomRadius
        case .expandedTamper, .expandedAlarm:
            return NotchGeometry.openBottomRadius
        }
    }

    public var body: some View {
        ZStack(alignment: .top) {
            if displayMode != .hidden {
                panelContainer
                    .padding(.top, geometry.style == .pill ? NotchGeometry.pillTopGap : 0)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.36, dampingFraction: 0.80), value: displayMode)
        .onAppear {
            let interactive = (displayMode == .compactArming || displayMode == .expandedTamper || displayMode == .expandedAlarm)
            onRequestInteractive(interactive, currentPanelSize)
        }
        .onChange(of: displayMode) { _, newMode in
            let interactive = (newMode == .compactArming || newMode == .expandedTamper || newMode == .expandedAlarm)
            onRequestInteractive(interactive, currentPanelSize)
            if !interactive {
                enteredPin = ""
            }
        }
    }

    private var panelContainer: some View {
        let flare = NotchGeometry.flareAllowance(topRadius: currentTopRadius, style: geometry.style)

        return ZStack(alignment: .top) {
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
            .shadow(color: Color.black.opacity(0.45), radius: 16, y: 6)

            if isMinimalWingMode {
                minimalWingContent
                    .padding(.horizontal, flare / 2)
                    .padding(.bottom, geometry.style == .notch ? Self.minimalExtraHeight : 0)
            } else {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: cameraIslandHeight)
                    expandedVisibleContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, flare / 2 + 16)
            }
        }
        .frame(width: currentPanelSize.width, height: currentPanelSize.height)
    }

    private var borderTint: Color {
        switch displayMode {
        case .expandedAlarm:
            return Color(red: 1.0, green: 0.27, blue: 0.23)
        case .expandedTamper:
            return Color(red: 1.0, green: 0.62, blue: 0.04)
        case .minimalGaze, .compactArming:
            return Color(white: 0.14)
        default:
            return Color(white: 0.12)
        }
    }

    /// Glance-style MinimalUnlockView layout: left and right wings flanking the physical camera cutout.
    @ViewBuilder
    private var minimalWingContent: some View {
        HStack(spacing: 0) {
            // Leading wing
            Group {
                if displayMode == .compactArming {
                    Button {
                        coordinator.cancelArmingDuringExitDelay()
                    } label: {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PupilTheme.warningAmber)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel arming")
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.90))
                }
            }
            .frame(width: Self.minimalSideWidth)

            Spacer(minLength: geometry.style == .notch ? geometry.closedSize.width : 28)

            // Trailing wing
            Group {
                if displayMode == .compactArming {
                    Text("\(coordinator.countdownSecondsRemaining)s")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PupilTheme.warningAmber)
                } else {
                    PupilEyeVectorView(
                        isOpen: true,
                        lookOffset: coordinator.eyeLookOffset,
                        accentColor: Color.white.opacity(0.92),
                        size: 18
                    )
                }
            }
            .frame(width: Self.minimalSideWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var expandedVisibleContent: some View {
        let isAlarm = (displayMode == .expandedAlarm)
        VStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: isAlarm ? "bell.badge.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isAlarm ? PupilTheme.alarmRed : PupilTheme.warningAmber)

                Text(isAlarm ? "Alarm active" : "Tamper detected — \(coordinator.countdownSecondsRemaining)s")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            .padding(.top, 4)

            if let src = coordinator.activeTamperSource {
                Text(src.rawValue)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.60))
            }

            HStack(spacing: 8) {
                SecureField("PIN", text: $enteredPin)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .frame(width: 96, height: 26)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.20), lineWidth: 1))
                    .onSubmit {
                        submitPin()
                    }

                Button {
                    submitPin()
                } label: {
                    Text("Unlock")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 12)
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
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.white.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                    .help("Unlock with Touch ID")
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.vertical, 6)
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

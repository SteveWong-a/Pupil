//
//  NotchGeometry.swift
//  Pupil
//
//  Hardware notch & Dynamic Island pill geometry modeled after Glance's NotchGeometry.
//

import AppKit
import CoreGraphics

public enum NotchPanelStyle: Sendable, Equatable {
    case notch
    case pill
}

public struct NotchGeometry: Sendable {
    public let closedSize: CGSize
    public let isPhysicalNotch: Bool

    public var style: NotchPanelStyle { isPhysicalNotch ? .notch : .pill }

    public static let notchOpenSize = CGSize(width: 320, height: 180)
    public static let pillClosedSize = CGSize(width: 96, height: 26)
    public static let pillOpenSize = CGSize(width: 300, height: 160)
    public static let pillTopGap: CGFloat = 6

    public static let closedTopRadius: CGFloat = 8
    public static let closedBottomRadius: CGFloat = 12
    public static let openTopRadius: CGFloat = 16
    public static let openBottomRadius: CGFloat = 34

    public static let shadowPadding: CGFloat = 28
    public static let hoverBump: CGFloat = 6

    public var hardwareNotchHeight: CGFloat {
        isPhysicalNotch ? max(32, closedSize.height) : 0
    }

    public static func flareAllowance(topRadius: CGFloat, style: NotchPanelStyle) -> CGFloat {
        style == .notch ? topRadius * 2 : 0
    }

    public static func windowSize(for style: NotchPanelStyle) -> CGSize {
        let base = style == .notch ? notchOpenSize : pillOpenSize
        return CGSize(
            width: base.width + shadowPadding * 2 + hoverBump + 60,
            height: base.height + shadowPadding + hoverBump + (style == .pill ? pillTopGap : 0) + 70
        )
    }

    @MainActor
    public static func forPreferredScreen() -> NotchGeometry {
        guard let screen = preferredScreen() else {
            return NotchGeometry(closedSize: pillClosedSize, isPhysicalNotch: false)
        }
        return forScreen(screen)
    }

    @MainActor
    public static func forScreen(_ screen: NSScreen) -> NotchGeometry {
        guard screen.safeAreaInsets.top > 0 else {
            return NotchGeometry(closedSize: pillClosedSize, isPhysicalNotch: false)
        }
        let leftPadding = screen.auxiliaryTopLeftArea?.width ?? 0
        let rightPadding = screen.auxiliaryTopRightArea?.width ?? 0
        let width = max(160, screen.frame.width - leftPadding - rightPadding)
        let height = screen.safeAreaInsets.top
        return NotchGeometry(closedSize: CGSize(width: width, height: height), isPhysicalNotch: true)
    }

    @MainActor
    public static func preferredScreen() -> NSScreen? {
        if let targetID = PupilSettings.shared.preferredDisplayID {
            if let match = NSScreen.screens.first(where: { $0.stableDisplayID == targetID }) {
                return match
            }
        }
        return NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
    }
}

extension NSScreen {
    public var stableDisplayID: String? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }
        return String(number)
    }

    public var isBuiltInDisplay: Bool {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return false
        }
        return CGDisplayIsBuiltin(number) != 0
    }
}

//
//  ScreenShieldWindow.swift
//  Pupil
//
//  Full-screen shielding panel at CGShieldingWindowLevel() that covers the entire display
//  with a frosted-glass privacy blur while armed, preventing screen snooping until disarmed.
//

import AppKit
import CoreGraphics

extension Notification.Name {
    public static let screenShieldOpenPrompt = Notification.Name("PupilScreenShieldOpenPrompt")
    public static let screenShieldDismissPrompt = Notification.Name("PupilScreenShieldDismissPrompt")
    public static let screenShieldDeleteKey = Notification.Name("PupilScreenShieldDeleteKey")
    public static let screenShieldSubmitPrompt = Notification.Name("PupilScreenShieldSubmitPrompt")
    public static let screenShieldDigitTyped = Notification.Name("PupilScreenShieldDigitTyped")
    public static let screenShieldFocusPrimary = Notification.Name("PupilScreenShieldFocusPrimary")
    public static let screenShieldSync = Notification.Name("PupilScreenShieldSync")
    public static let screenShieldAnyKeyPressed = Notification.Name("PupilScreenShieldAnyKeyPressed")
}

public final class ScreenShieldWindow: NSPanel {
    private static let shieldWindowLevel = NSWindow.Level(
        rawValue: Int(CGShieldingWindowLevel())
    )

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        level = Self.shieldWindowLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = false
        hidesOnDeactivate = false
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }

    public override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            NSApp.activate(ignoringOtherApps: true)
            makeKeyAndOrderFront(nil)
        }
        super.sendEvent(event)
    }

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            NotificationCenter.default.post(name: .screenShieldDismissPrompt, object: nil)
            return
        }
        NotificationCenter.default.post(name: .screenShieldAnyKeyPressed, object: nil)
        if event.keyCode == 51 || event.keyCode == 117 { // Delete (Backspace) / Forward Delete
            NotificationCenter.default.post(name: .screenShieldDeleteKey, object: nil)
            return
        }
        if event.keyCode == 36 || event.keyCode == 76 { // Return / Enter
            NotificationCenter.default.post(name: .screenShieldSubmitPrompt, object: nil)
            return
        }
        if let chars = event.characters, let first = chars.first, first.isNumber {
            NotificationCenter.default.post(name: .screenShieldDigitTyped, object: String(first))
            return
        }
        super.keyDown(with: event)
    }
}

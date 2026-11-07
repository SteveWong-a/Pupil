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
            makeKey()
        }
        super.sendEvent(event)
    }

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            NotificationCenter.default.post(name: .screenShieldDismissPrompt, object: nil)
            return
        }
        NotificationCenter.default.post(name: .screenShieldOpenPrompt, object: nil)
        super.keyDown(with: event)
    }
}

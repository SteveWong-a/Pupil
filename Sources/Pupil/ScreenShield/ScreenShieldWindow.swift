//
//  ScreenShieldWindow.swift
//  Pupil
//
//  Full-screen shielding panel at CGShieldingWindowLevel() that covers the entire display
//  with a frosted-glass privacy blur while armed, preventing screen snooping until disarmed.
//

import AppKit
import CoreGraphics

public final class ScreenShieldWindow: NSPanel {
    private static let shieldWindowLevel = NSWindow.Level(
        rawValue: Int(CGShieldingWindowLevel())
    )

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
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
    public override var canBecomeMain: Bool { false }
}


//
//  NotchWindow.swift
//  Pupil
//
//  Borderless, transparent NSPanel sitting at CGShieldingWindowLevel() + 1,
//  joining all spaces and full-screen apps without stealing focus.
//

import AppKit
import CoreGraphics

public final class NotchWindow: NSPanel {
    private static let overlayWindowLevel = NSWindow.Level(
        rawValue: Int(CGShieldingWindowLevel()) + 1
    )

    public var acceptsKey = false

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
        level = Self.overlayWindowLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true
    }

    public override var canBecomeKey: Bool { acceptsKey }
    public override var canBecomeMain: Bool { false }
}

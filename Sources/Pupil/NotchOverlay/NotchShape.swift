//
//  NotchShape.swift
//  Pupil
//
//  The MacBook Notch silhouette with concave top-corner flares into the menu bar,
//  and continuous-corner Dynamic Island pill fallback on non-notched displays.
//

import SwiftUI

public struct NotchShape: Shape {
    public var topRadius: CGFloat
    public var bottomRadius: CGFloat
    public var style: NotchPanelStyle = .notch

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    public init(topRadius: CGFloat, bottomRadius: CGFloat, style: NotchPanelStyle = .notch) {
        self.topRadius = topRadius
        self.bottomRadius = bottomRadius
        self.style = style
    }

    public func path(in rect: CGRect) -> Path {
        switch style {
        case .notch:
            return notchPath(in: rect)
        case .pill:
            return pillPath(in: rect)
        }
    }

    private func notchPath(in rect: CGRect) -> Path {
        let top = max(0, min(topRadius, rect.width / 2))
        let bottom = max(0, min(bottomRadius, min(rect.width / 2 - top, rect.height)))

        var path = Path()
        // Top-left concave flare outward to meet the top screen edge
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top, y: rect.minY + top),
            control: CGPoint(x: rect.minX + top, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY),
            control: CGPoint(x: rect.minX + top, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom),
            control: CGPoint(x: rect.maxX - top, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        // Top-right concave flare
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - top, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }

    private func pillPath(in rect: CGRect) -> Path {
        let limit = min(rect.width, rect.height) / 2
        let top = max(0, min(topRadius, limit))
        let bottom = max(0, min(bottomRadius, limit))
        return UnevenRoundedRectangle(
            topLeadingRadius: top,
            bottomLeadingRadius: bottom,
            bottomTrailingRadius: bottom,
            topTrailingRadius: top,
            style: .continuous
        ).path(in: rect)
    }
}

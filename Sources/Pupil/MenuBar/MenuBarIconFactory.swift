//
//  MenuBarIconFactory.swift
//  Pupil
//
//  Generates pixel-perfect, resolution-independent vector template icons for NSStatusBar.
//  Guaranteed to render sharp in light/dark mode and never fails on missing SF Symbols.
//

import AppKit

public enum MenuBarIconFactory {
    public static func makeStatusIcon(state: SecurityState, isGazeActive: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()

            let center = CGPoint(x: rect.midX, y: rect.midY)

            switch state {
            case .disarmed:
                // Minimalist precision aperture with resting horizontal pupil slit
                let outerRadius: CGFloat = 6.5
                let circlePath = CGPath(
                    ellipseIn: CGRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2),
                    transform: nil
                )
                context.addPath(circlePath)
                context.setLineWidth(1.4)
                context.setStrokeColor(NSColor.black.cgColor)
                context.strokePath()

                // Subtle resting horizontal slit (eye resting / standby)
                let slitWidth: CGFloat = 6.0
                let slitRect = CGRect(x: center.x - (slitWidth / 2), y: center.y - 0.7, width: slitWidth, height: 1.4)
                let slitPath = CGPath(roundedRect: slitRect, cornerWidth: 0.7, cornerHeight: 0.7, transform: nil)
                context.addPath(slitPath)
                context.setFillColor(NSColor.black.cgColor)
                context.fillPath()

            case .arming:
                // Sleek timer / quadrant arc
                let outerRadius: CGFloat = 6.5
                let arcPath = CGMutablePath()
                arcPath.addArc(center: center, radius: outerRadius, startAngle: -.pi / 2, endAngle: .pi, clockwise: false)
                context.addPath(arcPath)
                context.setLineWidth(1.4)
                context.setLineCap(.round)
                context.setStrokeColor(NSColor.black.cgColor)
                context.strokePath()

                // Center hand
                context.move(to: center)
                context.addLine(to: CGPoint(x: center.x, y: center.y + 4.5))
                context.move(to: center)
                context.addLine(to: CGPoint(x: center.x + 3.0, y: center.y))
                context.strokePath()

            case .armed:
                if isGazeActive {
                    // Active surveillance: double precision rings + solid pupil dot
                    let outerRadius: CGFloat = 7.0
                    let innerRadius: CGFloat = 4.2
                    let pupilRadius: CGFloat = 2.2

                    context.addEllipse(in: CGRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2))
                    context.setLineWidth(1.2)
                    context.setStrokeColor(NSColor.black.cgColor)
                    context.strokePath()

                    context.addEllipse(in: CGRect(x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2))
                    context.setLineWidth(1.0)
                    context.strokePath()

                    context.addEllipse(in: CGRect(x: center.x - pupilRadius, y: center.y - pupilRadius, width: pupilRadius * 2, height: pupilRadius * 2))
                    context.setFillColor(NSColor.black.cgColor)
                    context.fillPath()
                } else {
                    // Armed sentinel: clean solid outer circle with precise centered aperture
                    let outerRadius: CGFloat = 6.5
                    let pupilRadius: CGFloat = 2.5

                    context.addEllipse(in: CGRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2))
                    context.setLineWidth(1.4)
                    context.setStrokeColor(NSColor.black.cgColor)
                    context.strokePath()

                    context.addEllipse(in: CGRect(x: center.x - pupilRadius, y: center.y - pupilRadius, width: pupilRadius * 2, height: pupilRadius * 2))
                    context.setFillColor(NSColor.black.cgColor)
                    context.fillPath()
                }

            case .tamperPending, .alarm:
                // Sleek warning shield with alert mark
                let path = CGMutablePath()
                path.move(to: CGPoint(x: center.x, y: center.y + 7.5))
                path.addLine(to: CGPoint(x: center.x + 6.5, y: center.y + 4.0))
                path.addLine(to: CGPoint(x: center.x + 4.5, y: center.y - 6.5))
                path.addLine(to: CGPoint(x: center.x, y: center.y - 8.0))
                path.addLine(to: CGPoint(x: center.x - 4.5, y: center.y - 6.5))
                path.addLine(to: CGPoint(x: center.x - 6.5, y: center.y + 4.0))
                path.closeSubpath()

                context.addPath(path)
                context.setLineWidth(1.3)
                context.setStrokeColor(NSColor.black.cgColor)
                context.strokePath()

                // Exclamation bar and dot
                let barRect = CGRect(x: center.x - 0.7, y: center.y - 1.5, width: 1.4, height: 4.5)
                context.addRect(barRect)
                context.addEllipse(in: CGRect(x: center.x - 0.9, y: center.y - 4.5, width: 1.8, height: 1.8))
                context.setFillColor(NSColor.black.cgColor)
                context.fillPath()
            }

            context.restoreGState()
            return true
        }

        image.isTemplate = true
        return image
    }
}

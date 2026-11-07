#!/usr/bin/env swift
//
//  generate-icon.swift
//  Pupil
//
//  Renders a tactile macOS Sequoia / Big Sur 3D cushion AppIcon.icns.
//  Features a dual-layer 3D beveled squircle (obsidian outer frame + porcelain
//  inner pillow cushion) and a single-weight rounded viewfinder-eye glyph.
//

import AppKit
import CoreGraphics
import Foundation

let fileManager = FileManager.default
let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let resourcesDir = currentDir.appendingPathComponent("Resources")
try? fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

let size = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()

func appleSquirclePath(in rect: CGRect, cornerRadius r: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let minX = rect.minX, maxX = rect.maxX
    let minY = rect.minY, maxY = rect.maxY
    let k: CGFloat = 0.552284749831
    let c = r * k

    path.move(to: CGPoint(x: minX + r, y: maxY))
    path.addLine(to: CGPoint(x: maxX - r, y: maxY))
    path.addCurve(
        to: CGPoint(x: maxX, y: maxY - r),
        control1: CGPoint(x: maxX - r + c, y: maxY),
        control2: CGPoint(x: maxX, y: maxY - r + c)
    )
    path.addLine(to: CGPoint(x: maxX, y: minY + r))
    path.addCurve(
        to: CGPoint(x: maxX - r, y: minY),
        control1: CGPoint(x: maxX, y: minY + r - c),
        control2: CGPoint(x: maxX - r + c, y: minY)
    )
    path.addLine(to: CGPoint(x: minX + r, y: minY))
    path.addCurve(
        to: CGPoint(x: minX, y: minY + r),
        control1: CGPoint(x: minX + r - c, y: minY),
        control2: CGPoint(x: minX, y: minY + r - c)
    )
    path.addLine(to: CGPoint(x: minX, y: maxY - r))
    path.addCurve(
        to: CGPoint(x: minX + r, y: maxY),
        control1: CGPoint(x: minX, y: maxY - r + c),
        control2: CGPoint(x: minX + r - c, y: maxY)
    )
    path.closeSubpath()
    return path
}

guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Failed to create CGContext\n", stderr)
    exit(1)
}

ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)
ctx.interpolationQuality = .high

// 1. Outer 3D Cushion Squircle (Obsidian / Space Black)
let outerRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let outerPath = appleSquirclePath(in: outerRect, cornerRadius: 186)

ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: -14),
    blur: 28,
    color: CGColor(colorSpace: colorSpace, components: [0.0, 0.0, 0.0, 0.28])!
)
ctx.addPath(outerPath)
ctx.setFillColor(CGColor(colorSpace: colorSpace, components: [0.10, 0.11, 0.14, 1.0])!)
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(outerPath)
ctx.clip()

let outerGrad = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(colorSpace: colorSpace, components: [0.23, 0.25, 0.30, 1.0])!,
        CGColor(colorSpace: colorSpace, components: [0.09, 0.10, 0.13, 1.0])!
    ] as CFArray,
    locations: [0.0, 0.85]
)!
ctx.drawLinearGradient(
    outerGrad,
    start: CGPoint(x: 512, y: outerRect.maxY),
    end: CGPoint(x: 512, y: outerRect.minY),
    options: []
)

// Outer 3D cushion top highlight bevel
let outerInv = CGMutablePath()
outerInv.addRect(outerRect.insetBy(dx: -80, dy: -80))
outerInv.addPath(outerPath)
ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: -8),
    blur: 18,
    color: CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.30])!
)
ctx.addPath(outerInv)
ctx.fillPath(using: .evenOdd)
ctx.restoreGState()
ctx.restoreGState()

// 2. Inner 3D Cushion Squircle (Porcelain / Silver-Mist)
let innerRect = outerRect.insetBy(dx: 50, dy: 50)
let innerPath = appleSquirclePath(in: innerRect, cornerRadius: 150)

ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: -6),
    blur: 16,
    color: CGColor(colorSpace: colorSpace, components: [0.0, 0.0, 0.0, 0.42])!
)
ctx.addPath(innerPath)
ctx.setFillColor(CGColor(colorSpace: colorSpace, components: [0.95, 0.96, 0.99, 1.0])!)
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(innerPath)
ctx.clip()

let innerGrad = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(colorSpace: colorSpace, components: [0.995, 0.998, 1.0, 1.0])!,
        CGColor(colorSpace: colorSpace, components: [0.91, 0.93, 0.97, 1.0])!,
        CGColor(colorSpace: colorSpace, components: [0.83, 0.87, 0.93, 1.0])!
    ] as CFArray,
    locations: [0.0, 0.65, 1.0]
)!
ctx.drawLinearGradient(
    innerGrad,
    start: CGPoint(x: 512, y: innerRect.maxY),
    end: CGPoint(x: 512, y: innerRect.minY),
    options: []
)

// Soft inner pillow shadow along bottom/sides
let inv = CGMutablePath()
inv.addRect(innerRect.insetBy(dx: -80, dy: -80))
inv.addPath(innerPath)
ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: 10),
    blur: 28,
    color: CGColor(colorSpace: colorSpace, components: [0.22, 0.28, 0.42, 0.36])!
)
ctx.addPath(inv)
ctx.fillPath(using: .evenOdd)
ctx.restoreGState()

// Crisp top specular rim on inner cushion
ctx.saveGState()
ctx.addPath(innerPath.copy(strokingWithWidth: 10, lineCap: .round, lineJoin: .round, miterLimit: 10))
ctx.clip()
let rimGrad = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.95])!,
        CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.15])!
    ] as CFArray,
    locations: [0.0, 1.0]
)!
ctx.drawLinearGradient(
    rimGrad,
    start: CGPoint(x: 512, y: innerRect.maxY),
    end: CGPoint(x: 512, y: innerRect.minY),
    options: []
)
ctx.restoreGState()
ctx.restoreGState()

// 3. Center Mark: Viewfinder Corner Brackets + Clean Geometric Eye
let strokeColor = CGColor(colorSpace: colorSpace, components: [0.13, 0.15, 0.20, 1.0])!
ctx.saveGState()
ctx.setStrokeColor(strokeColor)
ctx.setFillColor(strokeColor)
ctx.setLineWidth(40)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

let b: CGFloat = 215
let arm: CGFloat = 68
let r: CGFloat = 54
let cx: CGFloat = 512, cy: CGFloat = 512

for (sx, sy) in [(-1.0, 1.0), (1.0, 1.0), (-1.0, -1.0), (1.0, -1.0)] {
    let p = CGMutablePath()
    let xCorner = cx + CGFloat(sx) * b
    let yCorner = cy + CGFloat(sy) * b
    let xEnd = cx + CGFloat(sx) * (b - arm)
    let yEnd = cy + CGFloat(sy) * (b - arm)
    p.move(to: CGPoint(x: xCorner, y: yEnd))
    p.addArc(tangent1End: CGPoint(x: xCorner, y: yCorner), tangent2End: CGPoint(x: xEnd, y: yCorner), radius: r)
    p.addLine(to: CGPoint(x: xEnd, y: yCorner))
    ctx.addPath(p)
    ctx.strokePath()
}

let ew: CGFloat = 138
let eh: CGFloat = 86
let eyePath = CGMutablePath()
eyePath.move(to: CGPoint(x: cx - ew, y: cy))
eyePath.addCurve(
    to: CGPoint(x: cx + ew, y: cy),
    control1: CGPoint(x: cx - ew * 0.55, y: cy + eh),
    control2: CGPoint(x: cx + ew * 0.55, y: cy + eh)
)
eyePath.addCurve(
    to: CGPoint(x: cx - ew, y: cy),
    control1: CGPoint(x: cx + ew * 0.55, y: cy - eh),
    control2: CGPoint(x: cx - ew * 0.55, y: cy - eh)
)
eyePath.closeSubpath()
ctx.setLineWidth(36)
ctx.addPath(eyePath)
ctx.strokePath()

ctx.addEllipse(in: CGRect(x: cx - 38, y: cy - 38, width: 76, height: 76))
ctx.fillPath()
ctx.restoreGState()

guard let cgImage = ctx.makeImage() else { exit(1) }
let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
bitmapRep.size = NSSize(width: size, height: size)
guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { exit(1) }

let tempPngPath = "/tmp/pupil_icon_1024.png"
let iconsetPath = "/tmp/Pupil.iconset"
try pngData.write(to: URL(fileURLWithPath: tempPngPath))

try? fileManager.removeItem(atPath: iconsetPath)
try fileManager.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let scales: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (px, name) in scales {
    let outFile = "\(iconsetPath)/\(name)"
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    proc.arguments = ["-z", "\(px)", "\(px)", tempPngPath, "--out", outFile]
    proc.standardOutput = Pipe()
    proc.standardError = Pipe()
    try proc.run()
    proc.waitUntilExit()
}

let icnsOutput = resourcesDir.appendingPathComponent("AppIcon.icns").path
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetPath, "-o", icnsOutput]
try iconutil.run()
iconutil.waitUntilExit()

print("Generated AppIcon.icns -> \(icnsOutput)")

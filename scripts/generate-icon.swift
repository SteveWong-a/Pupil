#!/usr/bin/env swift
import AppKit
import Foundation

let fileManager = FileManager.default
let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let resourcesDir = currentDir.appendingPathComponent("Resources")
try? fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

let size = NSSize(width: 1024, height: 1024)
let img = NSImage(size: size)
img.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else {
    fputs("Failed to get graphics context\n", stderr)
    exit(1)
}

// 1. macOS App Icon Squircle base (Apple continuous corner standard)
let squircleRect = CGRect(x: 90, y: 90, width: 844, height: 844)
let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: 190, cornerHeight: 190, transform: nil)

// Subtle drop shadow under squircle
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 36, color: CGColor(gray: 0, alpha: 0.45))
ctx.addPath(squirclePath)
ctx.setFillColor(CGColor(gray: 0.05, alpha: 1.0))
ctx.fillPath()
ctx.restoreGState()

// Base fill: dark obsidian radial gradient
ctx.saveGState()
ctx.addPath(squirclePath)
ctx.clip()
let colors = [
    CGColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0),
    CGColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1.0)
] as CFArray
let colorSpace = CGColorSpaceCreateDeviceRGB()
if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
    ctx.drawRadialGradient(
        gradient,
        startCenter: CGPoint(x: 512, y: 560),
        startRadius: 50,
        endCenter: CGPoint(x: 512, y: 512),
        endRadius: 500,
        options: []
    )
}

// Bezel rim stroke
ctx.addPath(squirclePath)
ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.14))
ctx.setLineWidth(8)
ctx.strokePath()
ctx.restoreGState()

// 2. Concentric Biometric Reticle & Guide Rings
let center = CGPoint(x: 512, y: 512)

// Outer guide ring
ctx.addEllipse(in: CGRect(x: center.x - 260, y: center.y - 260, width: 520, height: 520))
ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.18))
ctx.setLineWidth(4)
ctx.strokePath()

// 4-axis reticle tick marks
for deg in [0.0, 90.0, 180.0, 270.0] {
    let rad = deg * .pi / 180.0
    let x1 = center.x + cos(rad) * 240
    let y1 = center.y + sin(rad) * 240
    let x2 = center.x + cos(rad) * 280
    let y2 = center.y + sin(rad) * 280
    ctx.move(to: CGPoint(x: x1, y: y1))
    ctx.addLine(to: CGPoint(x: x2, y: y2))
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.40))
    ctx.setLineWidth(6)
    ctx.strokePath()
}

// Mid optical aperture ring
ctx.addEllipse(in: CGRect(x: center.x - 170, y: center.y - 170, width: 340, height: 340))
ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.30))
ctx.setLineWidth(5)
ctx.strokePath()

// Iris aperture glow
ctx.addEllipse(in: CGRect(x: center.x - 120, y: center.y - 120, width: 240, height: 240))
ctx.setFillColor(CGColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1.0))
ctx.fillPath()
ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.65))
ctx.setLineWidth(6)
ctx.strokePath()

// Razor pupil core
ctx.addEllipse(in: CGRect(x: center.x - 55, y: center.y - 55, width: 110, height: 110))
ctx.setFillColor(CGColor(gray: 0.02, alpha: 1.0))
ctx.fillPath()

// Specular catchlight
ctx.addEllipse(in: CGRect(x: center.x - 18, y: center.y + 14, width: 28, height: 28))
ctx.setFillColor(CGColor(gray: 0.95, alpha: 0.95))
ctx.fillPath()

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to convert image to PNG\n", stderr)
    exit(1)
}

let tempPngPath = "/tmp/pupil_icon_1024.png"
let iconsetPath = "/tmp/Pupil.iconset"
try png.write(to: URL(fileURLWithPath: tempPngPath))

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

for (dim, filename) in scales {
    let dest = "\(iconsetPath)/\(filename)"
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    task.arguments = ["-z", "\(dim)", "\(dim)", tempPngPath, "--out", dest]
    try task.run()
    task.waitUntilExit()
}

let icnsDest = resourcesDir.appendingPathComponent("AppIcon.icns").path
let iconutilTask = Process()
iconutilTask.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutilTask.arguments = ["-c", "icns", iconsetPath, "-o", icnsDest]
try iconutilTask.run()
iconutilTask.waitUntilExit()

try? fileManager.removeItem(atPath: tempPngPath)
try? fileManager.removeItem(atPath: iconsetPath)

print("Generated retina AppIcon.icns -> \(icnsDest)")


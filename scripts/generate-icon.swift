#!/usr/bin/env swift
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    fputs("usage: generate-icon.swift <input.svg> <output.icns> [safe-area-ratio]\n", stderr)
    exit(2)
}
let svgPath = args[1]
let icnsPath = args[2]
let safeAreaRatio: CGFloat = args.count >= 4 ? CGFloat(Double(args[3]) ?? 0.8) : 0.8

let svgURL = URL(fileURLWithPath: svgPath)
guard let svg = NSImage(contentsOf: svgURL) else {
    fputs("error: NSImage couldn't load \(svgPath)\n", stderr)
    exit(1)
}

let tmpRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kittt-icon-\(UUID().uuidString)")
let iconset = tmpRoot.appendingPathComponent("AppIcon.iconset")
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, filename) in sizes {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0, bitsPerPixel: 32
    ) else {
        fputs("error: couldn't create bitmap at \(size)\n", stderr)
        exit(1)
    }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    ctx.imageInterpolation = .high
    NSGraphicsContext.current = ctx

    let contentSize = CGFloat(size) * safeAreaRatio
    let inset = (CGFloat(size) - contentSize) / 2
    let drawRect = NSRect(x: inset, y: inset, width: contentSize, height: contentSize)
    svg.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)

    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        fputs("error: couldn't encode PNG for \(filename)\n", stderr)
        exit(1)
    }
    try! png.write(to: iconset.appendingPathComponent(filename))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", "-o", icnsPath, iconset.path]
try! task.run()
task.waitUntilExit()
if task.terminationStatus != 0 {
    fputs("iconutil failed (\(task.terminationStatus))\n", stderr)
    exit(task.terminationStatus)
}

try? FileManager.default.removeItem(at: tmpRoot)
print("wrote \(icnsPath)")

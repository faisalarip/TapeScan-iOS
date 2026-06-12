// generate-icon.swift — renders the TapeScan app icon (1024×1024 PNG).
//
// Design language mirrors the app: dark canvas, accent-blue (#3B82F6)
// measuring polyline with white-ringed nodes, tape ticks along the line,
// and a soft reticle glow — "AR measuring" at a glance, no text.
//
// Run:  swift scripts/generate-icon.swift <output.png>

import AppKit
import CoreGraphics

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon-1024.png"

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size,
                    bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgba(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let accent: UInt32 = 0x3B82F6

// MARK: background — vertical dark gradient
let bgGradient = CGGradient(colorsSpace: space,
                            colors: [rgba(0x1A1E26), rgba(0x0B0D11)] as CFArray,
                            locations: [0, 1])!
ctx.drawLinearGradient(bgGradient,
                       start: CGPoint(x: 0, y: CGFloat(size)),
                       end: .zero, options: [])

// faint horizontal grid (depth cue)
ctx.setStrokeColor(rgba(0xFFFFFF, 0.045))
ctx.setLineWidth(2)
for i in 1..<8 {
    let y = CGFloat(i) * CGFloat(size) / 8
    ctx.move(to: CGPoint(x: 0, y: y))
    ctx.addLine(to: CGPoint(x: CGFloat(size), y: y))
}
ctx.strokePath()

// MARK: reticle glow behind center
let center = CGPoint(x: 512, y: 512)
let glow = CGGradient(colorsSpace: space,
                      colors: [rgba(accent, 0.34), rgba(accent, 0.0)] as CFArray,
                      locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0,
                       endCenter: center, endRadius: 430, options: [])

// reticle ring + crosshair ticks
ctx.setStrokeColor(rgba(0xFFFFFF, 0.85))
ctx.setLineWidth(15)
ctx.addEllipse(in: CGRect(x: center.x - 235, y: center.y - 235, width: 470, height: 470))
ctx.strokePath()

ctx.setLineCap(.round)
ctx.setLineWidth(16)
for (dx, dy) in [(0.0, 1.0), (0.0, -1.0), (1.0, 0.0), (-1.0, 0.0)] {
    let inner = CGPoint(x: center.x + 235 * dx, y: center.y + 235 * dy)
    let outer = CGPoint(x: center.x + 295 * dx, y: center.y + 295 * dy)
    ctx.move(to: inner)
    ctx.addLine(to: outer)
}
ctx.strokePath()

// MARK: measuring line (diagonal through the reticle)
let nodeA = CGPoint(x: 256, y: 388)
let nodeB = CGPoint(x: 768, y: 636)

func drawSegment(width: CGFloat, color: CGColor) {
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.move(to: nodeA)
    ctx.addLine(to: nodeB)
    ctx.strokePath()
}
drawSegment(width: 58, color: rgba(accent, 0.30))   // glow underlay
drawSegment(width: 22, color: rgba(accent, 1.0))    // core line

// tape ticks perpendicular to the line
let dx = nodeB.x - nodeA.x, dy = nodeB.y - nodeA.y
let length = (dx * dx + dy * dy).squareRoot()
let (ux, uy) = (dx / length, dy / length)
let (px, py) = (-uy, ux)
ctx.setStrokeColor(rgba(0xFFFFFF, 0.92))
ctx.setLineWidth(11)
for i in 1...7 {
    let t = CGFloat(i) / 8
    let bx = nodeA.x + dx * t, by = nodeA.y + dy * t
    let tickLength: CGFloat = i % 4 == 0 ? 42 : 26
    ctx.move(to: CGPoint(x: bx - px * tickLength, y: by - py * tickLength))
    ctx.addLine(to: CGPoint(x: bx + px * tickLength, y: by + py * tickLength))
}
ctx.strokePath()

// MARK: endpoint nodes (dark disc, white ring, accent core)
for node in [nodeA, nodeB] {
    ctx.setFillColor(rgba(0x0A0C0F, 0.95))
    ctx.fillEllipse(in: CGRect(x: node.x - 58, y: node.y - 58, width: 116, height: 116))
    ctx.setStrokeColor(rgba(0xFFFFFF, 1))
    ctx.setLineWidth(16)
    ctx.strokeEllipse(in: CGRect(x: node.x - 50, y: node.y - 50, width: 100, height: 100))
    ctx.setFillColor(rgba(accent, 1))
    ctx.fillEllipse(in: CGRect(x: node.x - 22, y: node.y - 22, width: 44, height: 44))
}

// MARK: write PNG
let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath)")

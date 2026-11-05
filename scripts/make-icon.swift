// Draws mdview's app icon and writes it as an asset catalog icon set
// (roadmap 7.4). The icon is plain shapes drawn in code, so it can be
// remade or changed without any design tool:
//
//     swift scripts/make-icon.swift
//
// It writes App/Resources/Assets.xcassets/AppIcon.appiconset, which the
// app target picks up by itself. Run it from the repository root.
//
// The design follows the macOS icon grid: a rounded square 824 points wide
// on a 1024 canvas. On it, a white page with a folded corner, and the
// Markdown "M↓" mark in the background colour.

import AppKit

let output = URL(filePath: "App/Resources/Assets.xcassets/AppIcon.appiconset")

/// Draws the icon into the current context, in a 1024 × 1024 space.
func drawIcon(in context: CGContext) {
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // A flat blue tile. No gradient or shadows: flat colours compress
    // to a fraction of the size, and the app has to stay under 5 MB
    // (spec 8.4).
    context.addPath(tilePath)
    context.setFillColor(CGColor(red: 0.20, green: 0.45, blue: 0.92, alpha: 1))
    context.fillPath()

    // The page: white, with the top-right corner folded down.
    let page = CGRect(x: 262, y: 210, width: 500, height: 604)
    let fold: CGFloat = 130
    let pagePath = CGMutablePath()
    pagePath.move(to: CGPoint(x: page.minX + 36, y: page.minY))
    pagePath.addLine(to: CGPoint(x: page.maxX - 36, y: page.minY))
    pagePath.addQuadCurve(to: CGPoint(x: page.maxX, y: page.minY + 36), control: CGPoint(x: page.maxX, y: page.minY))
    pagePath.addLine(to: CGPoint(x: page.maxX, y: page.maxY - fold))
    pagePath.addLine(to: CGPoint(x: page.maxX - fold, y: page.maxY))
    pagePath.addLine(to: CGPoint(x: page.minX + 36, y: page.maxY))
    pagePath.addQuadCurve(to: CGPoint(x: page.minX, y: page.maxY - 36), control: CGPoint(x: page.minX, y: page.maxY))
    pagePath.addLine(to: CGPoint(x: page.minX, y: page.minY + 36))
    pagePath.addQuadCurve(to: CGPoint(x: page.minX + 36, y: page.minY), control: CGPoint(x: page.minX, y: page.minY))
    pagePath.closeSubpath()
    context.addPath(pagePath)
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fillPath()

    // The folded-over corner, slightly darker.
    let corner = CGMutablePath()
    corner.move(to: CGPoint(x: page.maxX - fold, y: page.maxY))
    corner.addLine(to: CGPoint(x: page.maxX - fold, y: page.maxY - fold + 20))
    corner.addQuadCurve(to: CGPoint(x: page.maxX - fold + 20, y: page.maxY - fold),
                        control: CGPoint(x: page.maxX - fold, y: page.maxY - fold))
    corner.addLine(to: CGPoint(x: page.maxX, y: page.maxY - fold))
    corner.closeSubpath()
    context.addPath(corner)
    context.setFillColor(CGColor(red: 0.80, green: 0.86, blue: 0.95, alpha: 1))
    context.fillPath()

    // "M↓", in the tile's blue.
    let ink = CGColor(red: 0.20, green: 0.45, blue: 0.92, alpha: 1)
    context.setStrokeColor(ink)
    context.setFillColor(ink)
    context.setLineWidth(46)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    let base: CGFloat = 400, top: CGFloat = 610
    let m = CGMutablePath()
    m.move(to: CGPoint(x: 330, y: base))
    m.addLine(to: CGPoint(x: 330, y: top))
    m.addLine(to: CGPoint(x: 410, y: 520))
    m.addLine(to: CGPoint(x: 490, y: top))
    m.addLine(to: CGPoint(x: 490, y: base))
    context.addPath(m)
    context.strokePath()

    // The arrow: a stem and a solid head.
    let arrowX: CGFloat = 625
    context.move(to: CGPoint(x: arrowX, y: top))
    context.addLine(to: CGPoint(x: arrowX, y: 480))
    context.strokePath()
    let head = CGMutablePath()
    head.move(to: CGPoint(x: arrowX - 78, y: 490))
    head.addLine(to: CGPoint(x: arrowX + 78, y: 490))
    head.addLine(to: CGPoint(x: arrowX, y: base - 18))
    head.closeSubpath()
    context.addPath(head)
    context.setLineWidth(20)
    context.drawPath(using: .fillStroke)
}

func png(pixels: Int) -> Data? {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
    let context = graphics.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(in: context)
    return bitmap.representation(using: .png, properties: [:])
}

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
var images: [String] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        guard let data = png(pixels: points * scale) else { print("couldn't draw \(name)"); exit(1) }
        try data.write(to: output.appending(path: name))
        images.append("""
                { "filename" : "\(name)", "idiom" : "mac", "scale" : "\(scale)x", "size" : "\(points)x\(points)" }
            """)
    }
}
let contents = """
    {
      "images" : [
    \(images.joined(separator: ",\n"))
      ],
      "info" : { "author" : "xcode", "version" : 1 }
    }

    """
try contents.write(to: output.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
try """
    { "info" : { "author" : "xcode", "version" : 1 } }

    """.write(to: output.deletingLastPathComponent().appending(path: "Contents.json"), atomically: true, encoding: .utf8)
print("Wrote \(images.count) images to \(output.path)")

import AppKit
import CoreText

// Renders the app icon (a cursor clicking an A/가 card pair) into an .iconset folder for iconutil.
// Shapes use a 100-unit, y-down design grid; its 4...96 square maps onto Apple's 824/1024 icon body.
let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
let paper = rgb(0xF1EFE8), ink = rgb(0x2C2C2A), backCard = rgb(0x5F5E5A), white = rgb(0xFFFFFF)

func render(_ px: Int) -> Data {
    let cg = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let canvas = CGFloat(px) / 1024
    let unit = canvas * 824 / 92
    cg.translateBy(x: 0, y: CGFloat(px)); cg.scaleBy(x: 1, y: -1)
    cg.scaleBy(x: canvas, y: canvas); cg.translateBy(x: 100, y: 100)
    cg.scaleBy(x: 824 / 92, y: 824 / 92); cg.translateBy(x: -4, y: -4)

    func card(_ rect: CGRect, fill: CGColor, stroke: CGColor? = nil) {
        let path = CGPath(roundedRect: rect, cornerWidth: 5, cornerHeight: 5, transform: nil)
        cg.addPath(path); cg.setFillColor(fill); cg.fillPath()
        if let stroke { cg.addPath(path); cg.setStrokeColor(stroke); cg.setLineWidth(2); cg.strokePath() }
    }
    // Like SVG text-anchor="middle": centered on the advance width, sitting on the given baseline.
    // Fonts are sized in device pixels so small renders get proper hinting.
    func text(_ string: String, size: CGFloat, weight: NSFont.Weight, color: CGColor, baseline: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size * unit, weight: weight),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
        cg.saveGState()
        cg.translateBy(x: baseline.x, y: baseline.y); cg.scaleBy(x: 1 / unit, y: -1 / unit)
        cg.textMatrix = .identity
        cg.textPosition = CGPoint(x: -CTLineGetTypographicBounds(line, nil, nil, nil) / 2, y: 0)
        CTLineDraw(line, cg)
        cg.restoreGState()
    }

    // Coordinates below are the approved 4-a mockup, unchanged.
    cg.addPath(CGPath(roundedRect: CGRect(x: 4, y: 4, width: 92, height: 92), cornerWidth: 22, cornerHeight: 22, transform: nil))
    cg.setFillColor(paper); cg.fillPath()

    cg.saveGState()
    cg.translateBy(x: 74, y: 27); cg.rotate(by: 10 * .pi / 180); cg.translateBy(x: -74, y: -27)
    card(CGRect(x: 62, y: 12, width: 24, height: 30), fill: backCard)
    text("가", size: 13, weight: .regular, color: white, baseline: CGPoint(x: 74, y: 32))
    cg.restoreGState()

    card(CGRect(x: 50, y: 20, width: 24, height: 30), fill: white, stroke: ink)
    text("A", size: 16, weight: .medium, color: ink, baseline: CGPoint(x: 62, y: 41))

    let cursor = CGMutablePath()
    cursor.addLines(between: [CGPoint(x: 24, y: 34), CGPoint(x: 24, y: 80), CGPoint(x: 35, y: 69), CGPoint(x: 43, y: 86),
                              CGPoint(x: 50, y: 83), CGPoint(x: 42, y: 66), CGPoint(x: 57, y: 66)])
    cursor.closeSubpath()
    cg.addPath(cursor); cg.setFillColor(ink); cg.setStrokeColor(ink); cg.setLineWidth(2); cg.setLineJoin(.round)
    cg.drawPath(using: .fillStroke)

    return NSBitmapImageRep(cgImage: cg.makeImage()!).representation(using: .png, properties: [:])!
}

for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try render(px).write(to: output.appendingPathComponent("icon_\(name).png"))
}

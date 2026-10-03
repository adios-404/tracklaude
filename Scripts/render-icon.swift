// Renders tracklaude's app icon — the Dial (ticket 15) — at every size an .iconset needs.
// Usage: swift Scripts/render-icon.swift <out.iconset dir> <master.png path>
// `make icon` runs this and `iconutil`; the resulting Packaging/AppIcon.icns is committed
// so `make bundle` (and CI) never needs to draw.
//
// Drawn with Core Graphics rather than converted from SVG so each size is rasterised
// natively, and the two smallest get their own simpler drawing (no ticks, heavier strokes)
// the way hand-tuned macOS icons do.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: render-icon.swift <out.iconset> <master.png>\n".data(using: .utf8)!)
    exit(2)
}

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
    )
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
}

/// macOS's icon body: a superellipse (n = 5) on the 824-unit grid inside the 1024 canvas.
func body() -> CGPath {
    let path = CGMutablePath()
    let (center, radius, n) = (512.0, 412.0, 5.0)
    for step in 0...720 {
        let t = Double(step) / 720 * 2 * .pi
        let (c, s) = (cos(t), sin(t))
        let x = center + radius * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n)
        let y = center + radius * (s < 0 ? -1 : 1) * pow(abs(s), 2 / n)
        step == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

/// A point on the dial's upper half-circle: f = 0 at the left, 1 at the right (y down).
func onDial(_ f: Double, radius: Double, center: CGPoint) -> CGPoint {
    CGPoint(x: center.x - radius * cos(.pi * f), y: center.y - radius * sin(.pi * f))
}

func arc(to f: Double, radius: Double, center: CGPoint) -> CGPath {
    let path = CGMutablePath()
    let steps = max(2, Int(f * 240))
    for i in 0...steps {
        let point = onDial(f * Double(i) / Double(steps), radius: radius, center: center)
        i == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    return path
}

func render(pixels: Int) -> CGImage {
    let small = pixels <= 32
    let scale = CGFloat(pixels) / 1024
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.interpolationQuality = .high
    // Work in 1024 units with y pointing down. Shadow offsets ignore the CTM, so they are
    // given in device pixels with y up.
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: scale, y: -scale)

    let tile = body()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 24 * scale, color: rgb(0x000000, 0.35))
    ctx.addPath(tile)
    ctx.setFillColor(rgb(0x1A2B4D))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([rgb(0x2D4878), rgb(0x0F1B33)]),
        start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: []
    )
    if !small {
        ctx.drawRadialGradient(
            gradient([rgb(0xFFFFFF, 0.13), rgb(0xFFFFFF, 0)]),
            startCenter: CGPoint(x: 360, y: 170), startRadius: 0,
            endCenter: CGPoint(x: 360, y: 170), endRadius: 640, options: []
        )
    }
    ctx.addPath(tile)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.09))
    ctx.setLineWidth(small ? 12 : 4)
    ctx.strokePath()
    ctx.restoreGState()

    let center = CGPoint(x: 512, y: 650)
    let radius = small ? 270.0 : 282.0
    let width: CGFloat = small ? 112 : 76
    let level = 0.7

    // Track, then the used part in mint → amber.
    ctx.setLineCap(.round)
    ctx.addPath(arc(to: 1, radius: radius, center: center))
    ctx.setStrokeColor(rgb(0xFFFFFF, small ? 0.2 : 0.14))
    ctx.setLineWidth(width)
    ctx.strokePath()

    ctx.saveGState()
    ctx.addPath(arc(to: level, radius: radius, center: center))
    ctx.setLineWidth(width)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([rgb(0x50D2A2), rgb(0xF4B740)]),
        start: CGPoint(x: center.x - radius - width / 2, y: 0), end: CGPoint(x: center.x + radius * 0.6, y: 0),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    ctx.restoreGState()

    if !small {
        for i in 0...10 {
            let major = i % 5 == 0
            let inner = radius + Double(width) / 2 + 26
            let outer = inner + (major ? 34 : 20)
            let f = Double(i) / 10
            ctx.move(to: onDial(f, radius: inner, center: center))
            ctx.addLine(to: onDial(f, radius: outer, center: center))
            ctx.setStrokeColor(rgb(0xFFFFFF, major ? 0.55 : 0.3))
            ctx.setLineWidth(9)
            ctx.strokePath()
        }
    }

    // Needle: tapered from the hub to the level, rounded at the tip.
    let direction = CGVector(dx: -cos(.pi * level), dy: -sin(.pi * level))
    let across = CGVector(dx: -direction.dy, dy: direction.dx)
    let length: CGFloat = small ? 214 : 236
    let base: CGFloat = small ? 30 : 19
    let tipHalf: CGFloat = small ? 9 : 5
    func at(_ along: CGFloat, _ side: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + direction.dx * along + across.dx * side,
            y: center.y + direction.dy * along + across.dy * side
        )
    }
    let hubRadius: CGFloat = small ? 60 : 48
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -4 * scale), blur: 10 * scale, color: rgb(0x000000, 0.35))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.move(to: at(-24, base))
    ctx.addLine(to: at(length, tipHalf))
    ctx.addLine(to: at(length, -tipHalf))
    ctx.addLine(to: at(-24, -base))
    ctx.closePath()
    ctx.fillPath()
    let tip = at(length, 0)
    ctx.fillEllipse(in: CGRect(x: tip.x - tipHalf, y: tip.y - tipHalf, width: tipHalf * 2, height: tipHalf * 2))
    ctx.fillEllipse(in: CGRect(x: center.x - hubRadius, y: center.y - hubRadius, width: hubRadius * 2, height: hubRadius * 2))
    ctx.endTransparencyLayer()
    ctx.restoreGState()
    let pin: CGFloat = small ? 22 : 17
    ctx.setFillColor(rgb(0x13213D))
    ctx.fillEllipse(in: CGRect(x: center.x - pin, y: center.y - pin, width: pin * 2, height: pin * 2))

    return ctx.makeImage()!
}

func write(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
        FileHandle.standardError.write("cannot write \(path)\n".data(using: .utf8)!)
        exit(1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        FileHandle.standardError.write("cannot finalize \(path)\n".data(using: .utf8)!)
        exit(1)
    }
}

let iconset = args[1]
for points in [16, 32, 128, 256, 512] {
    write(render(pixels: points), to: "\(iconset)/icon_\(points)x\(points).png")
    write(render(pixels: points * 2), to: "\(iconset)/icon_\(points)x\(points)@2x.png")
}
write(render(pixels: 1024), to: args[2])
print("OK: wrote \(iconset) and \(args[2])")

// Prints SVG path data for a line of text set in a (variable) font file, kerned by CoreText.
// Usage: swift glyphs.swift <font.ttf> <size> <wght> <wdth> <tracking-em> <text>
// Output (JSON): {"d": "...", "width": w, "ascent": a, "descent": d, "capHeight": c, "xHeight": x}
import CoreText
import Foundation

let a = CommandLine.arguments
let url = URL(fileURLWithPath: a[1]) as CFURL
let size = CGFloat(Double(a[2])!)
let (wght, wdth, tracking, text) = (Double(a[3])!, Double(a[4])!, CGFloat(Double(a[5])!), a[6])

let provider = CGDataProvider(url: url)!
let cgFont = CGFont(provider)!
func tag(_ s: String) -> Int { s.utf8.reduce(0) { $0 << 8 | Int($1) } }
let variations = [tag("wght"): wght, tag("wdth"): wdth] as CFDictionary
let desc = CTFontDescriptorCreateWithAttributes([kCTFontVariationAttribute: variations] as CFDictionary)
let font = CTFontCreateWithGraphicsFont(cgFont, size, nil, desc)

let attrs: [NSAttributedString.Key: Any] = [
    NSAttributedString.Key(kCTFontAttributeName as String): font,
    NSAttributedString.Key(kCTKernAttributeName as String): tracking * size,
]
let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

func fmt(_ v: CGFloat) -> String {
    let s = String(format: "%.2f", Double(v))
    return s.replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
}
var d = ""
for run in CTLineGetGlyphRuns(line) as! [CTRun] {
    let count = CTRunGetGlyphCount(run)
    var glyphs = [CGGlyph](repeating: 0, count: count)
    var positions = [CGPoint](repeating: .zero, count: count)
    CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
    CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
    for i in 0..<count {
        // y flipped: SVG's y grows downward from the baseline at 0.
        var t = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: positions[i].x, ty: 0)
        guard let path = CTFontCreatePathForGlyph(font, glyphs[i], &t) else { continue }
        path.applyWithBlock { element in
            let p = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint: d += "M\(fmt(p[0].x)) \(fmt(p[0].y))"
            case .addLineToPoint: d += "L\(fmt(p[0].x)) \(fmt(p[0].y))"
            case .addQuadCurveToPoint: d += "Q\(fmt(p[0].x)) \(fmt(p[0].y)) \(fmt(p[1].x)) \(fmt(p[1].y))"
            case .addCurveToPoint: d += "C\(fmt(p[0].x)) \(fmt(p[0].y)) \(fmt(p[1].x)) \(fmt(p[1].y)) \(fmt(p[2].x)) \(fmt(p[2].y))"
            case .closeSubpath: d += "Z"
            @unknown default: break
            }
        }
    }
}
let out: [String: Any] = [
    "d": d, "width": width - Double(tracking * size), "ascent": ascent, "descent": descent,
    "capHeight": CTFontGetCapHeight(font), "xHeight": CTFontGetXHeight(font),
]
print(String(data: try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys]), encoding: .utf8)!)

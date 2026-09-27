// Prints the outlines of a line of text as SVG path data, so the logo's wordmark can ship
// as vector artwork instead of bundling the font. Used by scripts/make_icons.py.
//
//   swift scripts/wordmark_outline.swift <font file> <text> <size in px>
//
// Output: JSON {"d": <path>, "advance": <width>, "bounds": [minX, minY, maxX, maxY]} with the
// origin at the left end of the baseline and y pointing down (SVG coordinates).
import CoreText
import Foundation

let args = CommandLine.arguments
guard args.count == 4, let size = Double(args[3]) else {
    FileHandle.standardError.write("usage: wordmark_outline.swift <font file> <text> <size>\n".data(using: .utf8)!)
    exit(2)
}
guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(URL(fileURLWithPath: args[1]) as CFURL) as? [CTFontDescriptor],
      let descriptor = descriptors.first else {
    FileHandle.standardError.write("could not read font at \(args[1])\n".data(using: .utf8)!)
    exit(1)
}

let font = CTFontCreateWithFontDescriptor(descriptor, size, nil)
let text = NSAttributedString(string: args[2], attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
let line = CTLineCreateWithAttributedString(text)

let path = CGMutablePath()
for run in CTLineGetGlyphRuns(line) as! [CTRun] {
    let count = CTRunGetGlyphCount(run)
    var glyphs = [CGGlyph](repeating: 0, count: count)
    var positions = [CGPoint](repeating: .zero, count: count)
    CTRunGetGlyphs(run, CFRange(), &glyphs)
    CTRunGetPositions(run, CFRange(), &positions)
    for (glyph, position) in zip(glyphs, positions) {
        guard let outline = CTFontCreatePathForGlyph(font, glyph, nil) else { continue }
        // Font space is y-up; flip to SVG's y-down with the baseline at y = 0.
        let transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: position.x, ty: -position.y)
        path.addPath(outline, transform: transform)
    }
}

func n(_ v: CGFloat) -> String {
    let s = String(format: "%.2f", Double(v))
    return s.hasSuffix(".00") ? String(s.dropLast(3)) : s
}

var d = ""
path.applyWithBlock { element in
    let p = element.pointee.points
    switch element.pointee.type {
    case .moveToPoint: d += "M\(n(p[0].x)) \(n(p[0].y))"
    case .addLineToPoint: d += "L\(n(p[0].x)) \(n(p[0].y))"
    case .addQuadCurveToPoint: d += "Q\(n(p[0].x)) \(n(p[0].y)) \(n(p[1].x)) \(n(p[1].y))"
    case .addCurveToPoint: d += "C\(n(p[0].x)) \(n(p[0].y)) \(n(p[1].x)) \(n(p[1].y)) \(n(p[2].x)) \(n(p[2].y))"
    case .closeSubpath: d += "Z"
    @unknown default: break
    }
}

let box = path.boundingBoxOfPath
let result: [String: Any] = [
    "d": d,
    "advance": Double(CTLineGetTypographicBounds(line, nil, nil, nil)),
    "bounds": [box.minX, box.minY, box.maxX, box.maxY].map(Double.init),
]
print(String(data: try JSONSerialization.data(withJSONObject: result), encoding: .utf8)!)

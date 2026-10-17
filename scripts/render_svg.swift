// Renders an SVG to a PNG at a given pixel height, drawn as vectors so it stays sharp.
// Usage: swift scripts/render_svg.swift input.svg output.png height
import AppKit

let args = CommandLine.arguments
guard args.count == 4, let image = NSImage(contentsOfFile: args[1]), let height = Double(args[3]) else {
    FileHandle.standardError.write("Usage: render_svg.swift input.svg output.png height\n".data(using: .utf8)!)
    exit(1)
}
let width = (height * image.size.width / image.size.height).rounded()
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))

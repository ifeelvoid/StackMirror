// Renders the app icon from the monochrome glyph in Assets/StackMirror-AppIcon.png.
// Usage: swift script/make_icon.swift <glyph.png> <out-1024.png>
// The glyph's dark pixels become a white mark on a dark macOS-shaped tile with transparent corners.
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let glyph = NSImage(contentsOfFile: args[1]),
      let glyphCG = glyph.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write(Data("usage: make_icon.swift <glyph.png> <out.png>\n".utf8))
    exit(2)
}

let canvas = 1024
// Apple's macOS icon grid: an 824pt body centred in 1024 with ~185pt continuous corners.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let space = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: canvas, height: canvas, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// Soft drop shadow under the tile, as system icons have.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: CGColor(gray: 0, alpha: 0.45))
let tile = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.addPath(tile)
ctx.setFillColor(CGColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1))
ctx.fillPath()
ctx.restoreGState()

// Subtle top-lit gradient inside the tile.
ctx.saveGState()
ctx.addPath(tile)
ctx.clip()
let gradient = CGGradient(colorsSpace: space, colors: [
    CGColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 1),
    CGColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1)
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: body.maxY), end: CGPoint(x: 512, y: body.minY), options: [])
ctx.restoreGState()

// Hairline edge so the tile reads on dark Docks.
ctx.addPath(CGPath(roundedRect: body.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 184, cornerHeight: 184, transform: nil))
ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.10))
ctx.setLineWidth(3)
ctx.strokePath()

// Glyph luminance → alpha mask: black ink becomes opaque, white paper becomes clear.
let gw = glyphCG.width, gh = glyphCG.height
let gray = CGContext(data: nil, width: gw, height: gh, bitsPerComponent: 8, bytesPerRow: gw,
                     space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
gray.draw(glyphCG, in: CGRect(x: 0, y: 0, width: gw, height: gh))
let pixels = gray.data!.bindMemory(to: UInt8.self, capacity: gw * gh)
for i in 0..<(gw * gh) { pixels[i] = 255 - pixels[i] }
let mask = gray.makeImage()!

let glyphRect = body.insetBy(dx: 120, dy: 120)
ctx.saveGState()
ctx.clip(to: glyphRect, mask: mask)
ctx.setFillColor(CGColor(gray: 0.96, alpha: 1))
ctx.fill(glyphRect)
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))

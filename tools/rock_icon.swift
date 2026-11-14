// Draw the launcher icon: a flat side-view curling rock, in the simple glyph
// style of Garmin's own activity icons.
//     swift tools/rock_icon.swift resources/drawables/launcher_icon.png 60
import AppKit

let args = CommandLine.arguments
let out = args.count > 1 ? args[1] : "launcher_icon.png"
let size = args.count > 2 ? Int(args[2])! : 60
// Drawn on a 100-unit canvas and scaled to the icon size
let s = CGFloat(size) / 100

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
ctx.scaleBy(x: s, y: s)
// Flip so y runs down like the design grid
ctx.translateBy(x: 0, y: 100)
ctx.scaleBy(x: 1, y: -1)

let granite = NSColor(red: 0.80, green: 0.83, blue: 0.86, alpha: 1).cgColor
let band = NSColor(red: 0.30, green: 0.33, blue: 0.37, alpha: 1).cgColor
let red = NSColor(red: 0.90, green: 0.16, blue: 0.18, alpha: 1).cgColor

// Stone: a wide body with rounded shoulders, sitting on the ice
let body = CGPath(roundedRect: CGRect(x: 8, y: 50, width: 84, height: 36), cornerWidth: 18, cornerHeight: 16,
                  transform: nil)
ctx.setFillColor(granite)
ctx.addPath(body)
ctx.fillPath()
// Striking band round the middle
ctx.saveGState()
ctx.addPath(body)
ctx.clip()
ctx.setFillColor(band)
ctx.fill(CGRect(x: 0, y: 64, width: 100, height: 8))
ctx.restoreGState()

// Handle: a post on top and a gooseneck reaching forward to a grip
ctx.setFillColor(red)
ctx.fill(CGRect(x: 40, y: 40, width: 14, height: 11))
let neck = CGMutablePath()
neck.move(to: CGPoint(x: 44, y: 42))
neck.addCurve(to: CGPoint(x: 66, y: 24), control1: CGPoint(x: 44, y: 28), control2: CGPoint(x: 54, y: 24))
neck.addLine(to: CGPoint(x: 84, y: 24))
ctx.setStrokeColor(red)
ctx.setLineWidth(10)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.addPath(neck)
ctx.strokePath()

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))

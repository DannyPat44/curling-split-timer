// Put whole simulator captures side by side, each scaled to the same height,
// to compare watches: swift tools/montage.swift out.png a.png b.png ...
import AppKit
let args = CommandLine.arguments
let images = args.dropFirst(2).compactMap { path -> CGImage? in
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}
let h = 520
let widths = images.map { Int(Double($0.width) * Double(h) / Double($0.height)) }
let ctx = CGContext(data: nil, width: widths.reduce(0, +), height: h, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
var x = 0
for (i, image) in images.enumerated() {
    ctx.draw(image, in: CGRect(x: x, y: 0, width: widths[i], height: h))
    x += widths[i]
}
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)

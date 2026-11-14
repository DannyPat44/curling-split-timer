// Tile simulator screenshots (tools/sim.swift shot) side by side, each
// cropped to the watch face, for looking over a run at a glance.
//     swift tools/tile.swift out.png a.png b.png ...
import AppKit
let args = CommandLine.arguments
// The watch face in a 2x capture of the simulator window, from the top left
let face = CGRect(x: 180, y: 420, width: 900, height: 1000)
let scale = 0.45
let images = args.dropFirst(2).compactMap { path -> CGImage? in
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)?.cropping(to: face)
}
let w = Int(face.width * scale), h = Int(face.height * scale)
let ctx = CGContext(data: nil, width: w * images.count, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
for (i, image) in images.enumerated() {
    ctx.draw(image, in: CGRect(x: i * w, y: 0, width: w, height: h))
}
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)

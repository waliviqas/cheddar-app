import CoreGraphics
import Vision

/*
This struct's only job is: Frame and tap in, the puck's box out.
*/
public struct PuckShapeFinder {
    public init() {}

    // Asks Vision to trace every shape at full size and returns the one under the tap, or nil on bare ice.
    // The box is in pixels with y measured from the bottom, same as the tap.
    public func puck(in frame: CGImage, near tap: CGPoint) -> CGRect? {
        guard let blackAndWhite = puckOnlyImage(of: frame, tap: tap) else { return nil }

        let request = VNDetectContoursRequest()
        request.maximumImageDimension = max(frame.width, frame.height)
        let handler = VNImageRequestHandler(cgImage: blackAndWhite)
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first else { return nil }

        var best: CGRect?
        for i in 0..<observation.contourCount {
            guard let contour = try? observation.contour(at: i) else { continue }
            let bb = contour.normalizedPath.boundingBoxOfPath
            let box = CGRect(
                x: bb.minX * CGFloat(frame.width),
                y: bb.minY * CGFloat(frame.height),
                width: bb.width * CGFloat(frame.width),
                height: bb.height * CGFloat(frame.height)
            )
            if box.contains(tap) && (best == nil || box.width < best!.width) {
                best = box
            }
        }
        return best
    }

    // Repaints the frame in pure black and white so Vision only sees the puck: black where a pixel matches the tapped color.
    // A pixel matches when it is closer to the tapped color than to the floor's average color, and not wildly different
    // from the tapped color, so shading on the puck still counts but a nearby line or shadow does not.
    // Returns nil when the tapped color is basically the floor's color, since that means the tap missed the puck.
    private func puckOnlyImage(of frame: CGImage, tap: CGPoint) -> CGImage? {
        let width = frame.width
        let height = frame.height
        guard let ctx = CGContext(
            data: nil,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(frame, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = ctx.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        let count = width * height
        var floor = (r: 0, g: 0, b: 0)
        for p in 0..<count {
            floor.r += Int(pixels[p * 4])
            floor.g += Int(pixels[p * 4 + 1])
            floor.b += Int(pixels[p * 4 + 2])
        }
        floor = (floor.r / count, floor.g / count, floor.b / count)

        // The tap is measured from the bottom; pixel rows are counted from the top.
        let t = ((height - 1 - Int(tap.y)) * width + Int(tap.x)) * 4
        let tapped = (r: Int(pixels[t]), g: Int(pixels[t + 1]), b: Int(pixels[t + 2]))

        // How different two colors are, squared, on a 0-255 scale per color.
        func difference(_ a: (r: Int, g: Int, b: Int), _ b: (r: Int, g: Int, b: Int)) -> Int {
            return (a.r - b.r) * (a.r - b.r) + (a.g - b.g) * (a.g - b.g) + (a.b - b.b) * (a.b - b.b)
        }

        guard difference(tapped, floor) >= 60 * 60 else { return nil }

        var shades = [UInt8](repeating: 255, count: count)
        for p in 0..<count {
            let pixel = (r: Int(pixels[p * 4]), g: Int(pixels[p * 4 + 1]), b: Int(pixels[p * 4 + 2]))
            let fromTapped = difference(pixel, tapped)
            if fromTapped < difference(pixel, floor) && fromTapped < 150 * 150 {
                shades[p] = 0
            }
        }

        guard let grayCtx = CGContext(
            data: &shades,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        return grayCtx.makeImage()
    }
}

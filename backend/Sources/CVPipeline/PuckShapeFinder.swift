import CoreGraphics
import Vision

// What the puck looks like, learned once from the setup tap: its color and its width in pixels.
public struct PuckLook: Sendable {
    public let color: CGColor
    public let width: Double

    public init(color: CGColor, width: Double) {
        self.color = color
        self.width = width
    }
}

/*
This struct's only job is: Frame in, puck boxes out — either the one under a tap, or every one that matches a look.
*/
public struct PuckShapeFinder {
    public init() {}

    private typealias Color = (r: Int, g: Int, b: Int)

    // Returns the box of the puck under the tap, or nil on bare ice.
    // The box is in pixels with y measured from the bottom, same as the tap.
    public func puck(in frame: CGImage, near tap: CGPoint) -> CGRect? {
        guard let (colors, floor) = readColors(of: frame) else { return nil }

        // The tap is measured from the bottom; pixel rows are counted from the top.
        let tapped = colors[(frame.height - 1 - Int(tap.y)) * frame.width + Int(tap.x)]

        // A tap that matches the floor's color missed the puck.
        guard difference(tapped, floor) >= 60 * 60 else { return nil }

        var best: CGRect?
        for box in shapes(in: frame, colors: colors, floor: floor, matching: tapped) {
            if box.contains(tap) && (best == nil || box.width < best!.width) {
                best = box
            }
        }
        return best
    }

    // Returns the box of every puck in the frame that matches the look, with no tap needed.
    // Same-colored things far off the puck's width are left out.
    // The ones sitting on plain floor come first: what surrounds them looks like the floor and unlike the puck.
    public func pucks(in frame: CGImage, like look: PuckLook) -> [CGRect] {
        guard let (colors, floor) = readColors(of: frame),
              let rgb = look.color.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)?.components
        else { return [] }
        let target = (r: Int(rgb[0] * 255), g: Int(rgb[1] * 255), b: Int(rgb[2] * 255))

        return shapes(in: frame, colors: colors, floor: floor, matching: target)
            .filter { abs($0.width - look.width) <= look.width / 2 }
            .map { box -> (box: CGRect, standout: Int) in
                let around = averageColor(around: box, in: frame, colors: colors)
                return (box, difference(around, target) - difference(around, floor))
            }
            .sorted { $0.standout > $1.standout }
            .map { $0.box }
    }

    // The average color of the area just around a box, the box itself included.
    private func averageColor(around box: CGRect, in frame: CGImage, colors: [Color]) -> Color {
        let grown = box.insetBy(dx: -box.width, dy: -box.height)
            .intersection(CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        guard !grown.isNull, grown.width >= 1, grown.height >= 1 else { return (0, 0, 0) }
        var total = (r: 0, g: 0, b: 0)
        var count = 0
        // Boxes measure y from the bottom; pixel rows are counted from the top.
        for row in (frame.height - Int(grown.maxY))..<(frame.height - Int(grown.minY)) {
            for col in Int(grown.minX)..<Int(grown.maxX) {
                let c = colors[row * frame.width + col]
                total = (total.r + c.r, total.g + c.g, total.b + c.b)
                count += 1
            }
        }
        return count > 0 ? (total.r / count, total.g / count, total.b / count) : (0, 0, 0)
    }

    // Repaints the frame in pure black and white, black where a pixel matches the target color,
    // then asks Vision to trace every shape at full size and returns their boxes.
    // A pixel matches when it is closer to the target than to the floor's average color, and not wildly different
    // from the target, so shading on the puck still counts but a nearby line or shadow does not.
    private func shapes(in frame: CGImage, colors: [Color], floor: Color, matching target: Color) -> [CGRect] {
        var shades = [UInt8](repeating: 255, count: colors.count)
        for (p, pixel) in colors.enumerated() {
            let fromTarget = difference(pixel, target)
            if fromTarget < difference(pixel, floor) && fromTarget < 150 * 150 {
                shades[p] = 0
            }
        }

        guard let grayCtx = CGContext(
            data: &shades,
            width: frame.width, height: frame.height,
            bitsPerComponent: 8, bytesPerRow: frame.width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ), let blackAndWhite = grayCtx.makeImage() else { return [] }

        let request = VNDetectContoursRequest()
        request.maximumImageDimension = max(frame.width, frame.height)
        let handler = VNImageRequestHandler(cgImage: blackAndWhite)
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first else { return [] }

        var boxes: [CGRect] = []
        for i in 0..<observation.contourCount {
            guard let contour = try? observation.contour(at: i) else { continue }
            let bb = contour.normalizedPath.boundingBoxOfPath
            // Outlines run along pixel edges, so round away Vision's tiny 0-1 rounding errors.
            let minX = (bb.minX * CGFloat(frame.width)).rounded()
            let minY = (bb.minY * CGFloat(frame.height)).rounded()
            let maxX = (bb.maxX * CGFloat(frame.width)).rounded()
            let maxY = (bb.maxY * CGFloat(frame.height)).rounded()
            boxes.append(CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
        }
        return boxes
    }

    // Unpacks every pixel's color, plus the floor's color as the average of the whole frame.
    private func readColors(of frame: CGImage) -> ([Color], Color)? {
        let count = frame.width * frame.height
        guard let ctx = CGContext(
            data: nil,
            width: frame.width, height: frame.height,
            bitsPerComponent: 8, bytesPerRow: frame.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(frame, in: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        guard let data = ctx.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: count * 4)

        var colors: [Color] = []
        colors.reserveCapacity(count)
        var total = (r: 0, g: 0, b: 0)
        for p in 0..<count {
            let pixel = (r: Int(pixels[p * 4]), g: Int(pixels[p * 4 + 1]), b: Int(pixels[p * 4 + 2]))
            colors.append(pixel)
            total = (total.r + pixel.r, total.g + pixel.g, total.b + pixel.b)
        }
        return (colors, (total.r / count, total.g / count, total.b / count))
    }

    // How different two colors are, squared, on a 0-255 scale per color.
    private func difference(_ a: Color, _ b: Color) -> Int {
        return (a.r - b.r) * (a.r - b.r) + (a.g - b.g) * (a.g - b.g) + (a.b - b.b) * (a.b - b.b)
    }
}

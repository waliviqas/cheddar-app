import CoreGraphics

/*
This class's only job is: Image in, puck position out per frame.
*/
public struct PuckTracker {
    public init() {}

    // Runs detect on every frame and bundles the answers into one list.
    // All frames go into track at once and then goes one by one for each.
    public func track(frames: [CGImage]) -> [CGPoint?] {
        return frames.map { detect(in: $0) }
    }

    // Finds the puck in one frame, or nil if there isn't one.
    public func detect(in frame: CGImage) -> CGPoint? {
        guard let pixels = readPixels(from: frame) else { return nil }
        let darkPixels = findDarkPixels(in: pixels, width: frame.width, height: frame.height)
        return centerOfMass(of: darkPixels, imageHeight: frame.height)
    }

    // Unpacks the image into a list of every pixel's color
    private func readPixels(from frame: CGImage) -> [UInt8]? {
        guard let ctx = CGContext(
            data: nil,
            width: frame.width, height: frame.height,
            bitsPerComponent: 8, bytesPerRow: frame.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(frame, in: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        guard let data = ctx.data else { return nil }
        let buffer = data.bindMemory(to: UInt8.self, capacity: frame.width * frame.height * 4)
        return Array(UnsafeBufferPointer(start: buffer, count: frame.width * frame.height * 4))
    }

    // Walks through that list and records where the dark ones are.
    private func findDarkPixels(in pixels: [UInt8], width: Int, height: Int) -> [CGPoint] {
        var dark: [CGPoint] = []
        for row in 0..<height {
            for col in 0..<width {
                let i = (row * width + col) * 4
                let brightness = Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])
                if brightness < 384 {
                    dark.append(CGPoint(x: Double(col) + 0.5, y: Double(row) + 0.5))
                }
            }
        }
        return dark
    }

    // Averages the dark pixel positions to get the puck's center.
    private func centerOfMass(of points: [CGPoint], imageHeight: Int) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        let sumX = points.reduce(0.0) { $0 + $1.x }
        let sumY = points.reduce(0.0) { $0 + $1.y }
        return CGPoint(
            x: sumX / Double(points.count),
            y: Double(imageHeight) - sumY / Double(points.count)
        )
    }
}

import CoreGraphics

/*
This struct's only job is: Tapped puck in, pixels per inch out.
*/
public struct PuckRuler {
    public init() {}

    // Asks PuckDetector for the puck nearest the tap, measures its real width, then divides by the puck's 3 inches.
    public func pixelsPerInch(in frame: CGImage, tappedAt tap: CGPoint) -> Double? {
        let nearest = PuckDetector().pucks(in: frame).min {
            hypot($0.midX - tap.x, $0.midY - tap.y) < hypot($1.midX - tap.x, $1.midY - tap.y)
        }
        guard let box = nearest, let width = puckWidth(in: frame, around: box) else { return nil }
        return Double(width) / 3
    }

    // The model's box is loose, so the edges are found inside it: starting from the pixel least like the floor around
    // the box, it spreads over every pixel at least a third as unlike the floor, and measures how wide that shape is.
    private func puckWidth(in frame: CGImage, around box: CGRect) -> Int? {
        let w = frame.width, h = frame.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.draw(frame, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: w * h * 4)

        let minX = max(3, Int(box.minX)), maxX = min(w - 4, Int(box.maxX))
        let top = max(3, h - Int(box.maxY)), bottom = min(h - 4, h - Int(box.minY))
        guard minX < maxX, top < bottom else { return nil }

        func color(_ x: Int, _ y: Int) -> [Double] {
            let i = (y * w + x) * 4
            return [Double(pixels[i]), Double(pixels[i + 1]), Double(pixels[i + 2])]
        }
        var ring: [[Double]] = []
        for x in (minX - 3)...(maxX + 3) {
            ring.append(color(x, top - 3))
            ring.append(color(x, bottom + 3))
        }
        for y in (top - 3)...(bottom + 3) {
            ring.append(color(minX - 3, y))
            ring.append(color(maxX + 3, y))
        }
        let floor = (0..<3).map { k in ring.map { $0[k] }.sorted()[ring.count / 2] }
        func unlikeFloor(_ x: Int, _ y: Int) -> Double {
            let c = color(x, y)
            return ((c[0] - floor[0]) * (c[0] - floor[0]) + (c[1] - floor[1]) * (c[1] - floor[1])
                    + (c[2] - floor[2]) * (c[2] - floor[2])).squareRoot()
        }

        var most = 0.0, seed = (minX, top)
        for y in top...bottom {
            for x in minX...maxX where unlikeFloor(x, y) > most {
                most = unlikeFloor(x, y)
                seed = (x, y)
            }
        }
        let cutoff = most / 3
        var seen: Set<Int> = [seed.1 * w + seed.0]
        var queue = [seed]
        var left = seed.0, right = seed.0
        while let (x, y) = queue.popLast() {
            for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
            where nx >= minX - 3 && nx <= maxX + 3 && ny >= top - 3 && ny <= bottom + 3 {
                guard !seen.contains(ny * w + nx), unlikeFloor(nx, ny) > cutoff else { continue }
                seen.insert(ny * w + nx)
                queue.append((nx, ny))
                left = min(left, nx)
                right = max(right, nx)
            }
        }
        return right - left + 1
    }
}

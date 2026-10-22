import CoreGraphics

/*
This struct's only job is: Tapped puck in, pixels per inch out.
*/
public struct PuckRuler {
    public init() {}

    // Measures every row of the puck under the tap, keeps the widest, then divides by the puck's real 3 inches.
    public func pixelsPerInch(in frame: CGImage, tappedAt tap: CGPoint) -> Double? {
        guard let ctx = CGContext(
            data: nil,
            width: frame.width, height: frame.height,
            bitsPerComponent: 8, bytesPerRow: frame.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(frame, in: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        guard let data = ctx.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: frame.width * frame.height * 4)
        // The tap is measured from the bottom; pixel rows are counted from the top.
        let tapRow = frame.height - Int(tap.y)
        let tapCol = Int(tap.x)

        func isDark(_ col: Int, _ row: Int) -> Bool {
            let i = (row * frame.width + col) * 4
            return Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2]) < 384
        }

        func width(of row: Int) -> Int {
            var left = tapCol
            while isDark(left - 1, row) { left -= 1 }
            var right = tapCol
            while isDark(right + 1, row) { right += 1 }
            return right - left + 1
        }

        var top = tapRow
        while isDark(tapCol, top - 1) { top -= 1 }
        var bottom = tapRow
        while isDark(tapCol, bottom + 1) { bottom += 1 }
        let widest = (top...bottom).map(width).max()!
        return Double(widest) / 3
    }
}

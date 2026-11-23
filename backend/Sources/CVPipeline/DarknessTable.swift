/*
This class's only job is: turn the camera's 420 colors into today's darkness number with quick lookups instead of color math.

420 is a brightness number for every pixel plus a blue-ness (Cb) and a red-ness (Cr) number shared by each 2×2 block.
Darkness is 255 minus the bigger of red and green, so black and blue pucks are both dark. The bigger of red and green is the
brightness plus a part that depends only on the color, so each pixel is two lookups and an add. It uses the camera's own color
math (BT.709). Video range keeps black at 16 and white at 235; full range uses 0 to 255.
*/
struct DarknessTable: Sendable {
    // In sixteenths, so the two parts can be added and then rounded once.
    private let luma: [Int16], chroma: [Int16]
    // The brightness part as (brightness × a + b) >> 16, equal to `luma` for all 256 brightness numbers, so a whole row can
    // be worked out 16 pixels at a time without lookups. Nil if no such pair exists.
    private let brightness: (a: Int32, b: Int32)?

    init(fullRange: Bool) {
        let yScale = fullRange ? 1.0 : 255.0 / 219, yOffset = fullRange ? 0.0 : 16, cScale = fullRange ? 1.0 : 255.0 / 224
        let luma = (0..<256).map { Int16(((Double($0) - yOffset) * yScale * 16).rounded()) }
        self.luma = luma
        chroma = (0..<65536).map { i in
            let blue = (Double(i >> 8) - 128) * cScale, red = (Double(i & 255) - 128) * cScale
            return Int16((max(1.5748 * red, -0.1873 * blue - 0.4681 * red) * 16).rounded())
        }
        let slope = Int((yScale * 16 * 65536).rounded())
        brightness = (slope - 16...slope + 16).lazy.compactMap { a -> (a: Int32, b: Int32)? in
            let low = (0..<256).map { Int(luma[$0]) << 16 - $0 * a }.max()!
            let high = (0..<256).map { (Int(luma[$0]) + 1) << 16 - $0 * a }.min()!
            guard low < high else { return nil }
            let b = low + (high - low) / 2
            return (0..<256).allSatisfy { (Int32($0) &* Int32(a) &+ Int32(b)) &>> 16 == Int32(luma[$0]) } ? (Int32(a), Int32(b)) : nil
        }.first
    }

    static let videoRange = DarknessTable(fullRange: false), fullRange = DarknessTable(fullRange: true)

    func darkness(y: UInt8, cb: UInt8, cr: UInt8) -> UInt8 {
        let redOrGreen = (Int(luma[Int(y)]) + Int(chroma[Int(cb) << 8 | Int(cr)]) + 8) >> 4
        return 255 - UInt8(min(max(redOrGreen, 0), 255))
    }

    // The color part of darkness(y:cb:cr:) for each pixel of one strip row, from the frame's color row. The two rows of a
    // 2×2 block share it.
    func colorParts(_ colors: UnsafePointer<UInt8>, firstColumn: Int, count: Int, into out: UnsafeMutablePointer<Int32>) {
        chroma.withUnsafeBufferPointer { chroma in
            var x = 0
            while x < count {
                let pair = (firstColumn + x) / 2 * 2
                out[x] = Int32(chroma[Int(colors[pair]) << 8 | Int(colors[pair + 1])])
                if (firstColumn + x) % 2 == 0, x + 1 < count {
                    out[x + 1] = out[x]
                    x += 2
                } else {
                    x += 1
                }
            }
        }
    }

    // darkness(y:cb:cr:) for one strip row, from its brightness row and its colorParts.
    func darkness(_ brightness: UnsafePointer<UInt8>, colorParts: UnsafePointer<Int32>, count: Int, into out: UnsafeMutablePointer<UInt8>) {
        guard let (a, b) = self.brightness else {
            for x in 0..<count {
                let redOrGreen = (Int32(luma[Int(brightness[x])]) &+ colorParts[x] &+ 8) &>> 4
                out[x] = 255 &- UInt8(truncatingIfNeeded: min(max(redOrGreen, 0), 255))
            }
            return
        }
        for x in 0..<count {
            let redOrGreen = (((Int32(brightness[x]) &* a &+ b) &>> 16) &+ colorParts[x] &+ 8) &>> 4
            out[x] = 255 &- UInt8(truncatingIfNeeded: min(max(redOrGreen, 0), 255))
        }
    }
}

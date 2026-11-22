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

    init(fullRange: Bool) {
        let yScale = fullRange ? 1.0 : 255.0 / 219, yOffset = fullRange ? 0.0 : 16, cScale = fullRange ? 1.0 : 255.0 / 224
        luma = (0..<256).map { Int16(((Double($0) - yOffset) * yScale * 16).rounded()) }
        chroma = (0..<65536).map { i in
            let blue = (Double(i >> 8) - 128) * cScale, red = (Double(i & 255) - 128) * cScale
            return Int16((max(1.5748 * red, -0.1873 * blue - 0.4681 * red) * 16).rounded())
        }
    }

    static let videoRange = DarknessTable(fullRange: false), fullRange = DarknessTable(fullRange: true)

    func darkness(y: UInt8, cb: UInt8, cr: UInt8) -> UInt8 {
        let redOrGreen = (Int(luma[Int(y)]) + Int(chroma[Int(cb) << 8 | Int(cr)]) + 8) >> 4
        return 255 - UInt8(min(max(redOrGreen, 0), 255))
    }
}

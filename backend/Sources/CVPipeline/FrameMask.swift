import CoreGraphics

/*
This class's only job is: hold which pixels of a picture are the goal frame (SAM 3's colored-in frame).
*/
public struct FrameMask {
    public let width: Int
    public let height: Int
    public let isFrame: [Bool]   // one per pixel, row by row from the top-left

    public init(width: Int, height: Int, isFrame: [Bool]) {
        self.width = width
        self.height = height
        self.isFrame = isFrame
    }

    // Reads a black-and-white mask picture: white means frame.
    public init?(image: CGImage) {
        let width = image.width, height = image.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &rgba, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        self.init(width: width, height: height, isFrame: (0..<(width * height)).map { rgba[$0 * 4] > 127 })
    }
}

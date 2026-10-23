import CoreGraphics

/*
This struct's only job is: Tapped puck in, pixels per inch out.
*/
public struct PuckRuler {
    public init() {}

    // Asks PuckShapeFinder for the puck under the tap, then divides its width by the puck's real 3 inches.
    public func pixelsPerInch(in frame: CGImage, tappedAt tap: CGPoint) -> Double? {
        guard let box = PuckShapeFinder().puck(in: frame, near: tap) else { return nil }
        return Double(box.width) / 3
    }
}

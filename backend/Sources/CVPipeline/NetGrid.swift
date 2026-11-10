import CoreGraphics
import simd

/*
This class's only job is: lay a 3 × 3 grid over the net opening, and say which square (if any) a puck went through.

The opening is measured on the front of the net, in inches: across from the left post (0) to the right post (72),
up from the ice (0) to the crossbar (48).
*/
public struct NetGrid {
    public struct Line { public let start: CGPoint; public let end: CGPoint }

    // The grid's 4 inside lines in the picture, in pixels: the 2 up-and-down lines, then the 2 side-to-side lines.
    public let lines: [Line]
    private let cornerBend: Double

    static let width = 72.0, height = 48.0
    static let puckRadius = 1.5      // a puck is 3 in across
    static let frameThickness = 2.375 // the posts and crossbar are 2⅜ in tubes

    // `cornerBend` is how rounded the opening's top corners are, in inches (0 = square).
    public init(pose: CameraPose, lens: LensInfo, cornerBend: Double = 0) {
        self.cornerBend = cornerBend
        func picture(_ across: Double, _ up: Double) -> CGPoint {
            // The spot on the front of the net, as the camera sees it, then onto the picture.
            let seen = pose.toCamera * (SIMD3(across, 0, up) - pose.position)
            return CGPoint(x: lens.centerX + lens.zoom * seen.x / seen.z, y: lens.centerY + lens.zoom * seen.y / seen.z)
        }
        let w = Self.width, h = Self.height
        lines = [
            Line(start: picture(w / 3, 0), end: picture(w / 3, h)),
            Line(start: picture(2 * w / 3, 0), end: picture(2 * w / 3, h)),
            Line(start: picture(0, h / 3), end: picture(w, h / 3)),
            Line(start: picture(0, 2 * h / 3), end: picture(w, 2 * h / 3)),
        ]
    }

    // Where the middle of the puck crossed the goal line: inches across from the left post, inches up from the ice.
    // It only counts as in when the whole puck fits inside the opening; then it's named by the square its middle is in,
    // and a middle exactly on a grid line goes to the square closer to the middle of the net.
    public func square(across x: Double, up z: Double) -> NetSquare {
        guard fitsInside(x, z) else { return touchesFrame(x, z) ? .post : .missed }

        let w = Self.width, h = Self.height
        let column = x < w / 3 ? 0 : (x > 2 * w / 3 ? 2 : 1)
        let row = z > 2 * h / 3 ? 0 : (z < h / 3 ? 2 : 1)
        return [[.topLeft, .topMiddle, .topRight],
                [.middleLeft, .middle, .middleRight],
                [.bottomLeft, .bottomMiddle, .bottomRight]][row][column]
    }

    private func fitsInside(_ x: Double, _ z: Double) -> Bool {
        let r = Self.puckRadius, w = Self.width, h = Self.height
        guard x - r >= 0, x + r <= w, z + r <= h, z >= 0 else { return false }
        // In a rounded top corner, the puck has to fit inside the curve too.
        let b = cornerBend
        guard b > 0, z > h - b, x < b || x > w - b else { return true }
        let center = SIMD2(x < b ? b : w - b, h - b)
        return simd_distance(SIMD2(x, z), center) <= b - r
    }

    // Whether any part of the puck touches the posts or crossbar (the opening plus the frame around it).
    private func touchesFrame(_ x: Double, _ z: Double) -> Bool {
        let r = Self.puckRadius, t = Self.frameThickness
        let nearestX = min(max(x, -t), Self.width + t), nearestZ = min(max(z, 0), Self.height + t)
        return simd_distance(SIMD2(x, z), SIMD2(nearestX, nearestZ)) <= r
    }
}

public enum NetSquare: Equatable {
    case topLeft, topMiddle, topRight
    case middleLeft, middle, middleRight
    case bottomLeft, bottomMiddle, bottomRight
    case post      // touched the frame, so not fully in
    case missed    // nowhere near the opening
}

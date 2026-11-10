import CoreGraphics
import simd

/*
This class's only job is: turn a spot in the picture into where it really is on the ice, in inches.
*/
public struct FloorSpot {
    private let pose: CameraPose
    private let lens: LensInfo

    public init(pose: CameraPose, lens: LensInfo) {
        self.pose = pose
        self.lens = lens
    }

    // (x along the goal line, y out from the goal) in inches, or nil if that spot in the picture isn't on the ice.
    public func spot(at pixel: CGPoint) -> SIMD2<Double>? {
        // The line of sight through that pixel, first as the camera sees it, then in net directions.
        let seen = SIMD3((Double(pixel.x) - lens.centerX) / lens.zoom, (Double(pixel.y) - lens.centerY) / lens.zoom, 1)
        let sight = pose.toCamera.transpose * seen
        // Follow it from the camera until it reaches the ice (height 0). If it never heads down, it never gets there.
        guard sight.z < -1e-9 else { return nil }
        let steps = -pose.position.z / sight.z
        return SIMD2(pose.position.x + steps * sight.x, pose.position.y + steps * sight.y)
    }
}

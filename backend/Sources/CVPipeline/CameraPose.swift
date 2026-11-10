import CoreGraphics
import simd

/*
This class's only job is: work out where the phone is and which way it's aimed, from the net's 4 inside corners.

Net coordinates, in inches: x runs along the goal line from the left post to the right post,
y runs out of the goal toward the shooter, z runs up from the ice.
*/
public struct CameraPose: Equatable {
    public let position: SIMD3<Double>   // where the camera is
    public let forward: SIMD3<Double>    // which way it's aimed
    let toCamera: simd_double3x3         // turns a net direction into the camera's own directions

    public var heightAboveIce: Double { position.z }
    public var distanceFromGoalLine: Double { position.y }

    // The opening's real inside size: 6 ft wide, 4 ft tall.
    static let netWidth = 72.0, netHeight = 48.0

    // Corners go top-left, top-right, bottom-right, bottom-left, in pixels (y down).
    public init?(corners: [CGPoint], lens: LensInfo) {
        guard corners.count == 4, lens.zoom > 0 else { return nil }

        // Each corner as a direction out of the lens (pixels → "how far right and down per unit forward").
        let seen = corners.map { SIMD2((Double($0.x) - lens.centerX) / lens.zoom, (Double($0.y) - lens.centerY) / lens.zoom) }
        // The same corners on the flat front of the net, as (across, up) in inches.
        let onNet = [SIMD2(0, Self.netHeight), SIMD2(Self.netWidth, Self.netHeight), SIMD2(Self.netWidth, 0), SIMD2(0, 0)]

        // The flat net and the picture are tied by one 3×3 "stretch" (a homography); solve it from the 4 pairs.
        guard let h = Self.homography(from: onNet, to: seen) else { return nil }

        // Its columns are the net's "across" and "up" directions and the net's corner, all as the camera sees them,
        // scaled by one unknown amount. Undo the scale, keeping the net in front of the camera.
        var across = h.columns.0, up = h.columns.1, corner = h.columns.2
        var scale = 2 / (simd_length(across) + simd_length(up))
        if corner.z * scale < 0 { scale = -scale }
        across *= scale; up *= scale; corner *= scale

        // Clean up small errors so the three directions are exactly square to each other.
        let x = simd_normalize(across)
        let z = simd_normalize(up - simd_dot(up, x) * x)
        let y = simd_cross(x, z)   // x along the goal line, z up, so y points out of the goal toward the camera
        let toCamera = simd_double3x3(columns: (x, y, z))   // net direction → camera direction

        let position = -(toCamera.transpose * corner)
        let forward = toCamera.transpose * SIMD3(0, 0, 1)
        guard position.x.isFinite, position.y.isFinite, position.z.isFinite, position.y > 0 else { return nil }

        self.position = position
        self.forward = forward
        self.toCamera = toCamera
    }

    // Solves the 3×3 map that sends each flat point a to picture point b (with the last entry fixed at 1).
    // Returns nil when the points can't pin it down, like 4 points in a line.
    private static func homography(from a: [SIMD2<Double>], to b: [SIMD2<Double>]) -> simd_double3x3? {
        var rows: [[Double]] = []
        for (p, q) in zip(a, b) {
            rows.append([p.x, p.y, 1, 0, 0, 0, -q.x * p.x, -q.x * p.y, q.x])
            rows.append([0, 0, 0, p.x, p.y, 1, -q.y * p.x, -q.y * p.y, q.y])
        }
        guard let h = solve(rows) else { return nil }
        return simd_double3x3(rows: [SIMD3(h[0], h[1], h[2]), SIMD3(h[3], h[4], h[5]), SIMD3(h[6], h[7], 1)])
    }

    // Plain row-by-row elimination for 8 equations, 8 unknowns (last column is the right-hand side).
    private static func solve(_ input: [[Double]]) -> [Double]? {
        var m = input
        let n = 8
        for col in 0..<n {
            guard let pivot = (col..<n).max(by: { abs(m[$0][col]) < abs(m[$1][col]) }), abs(m[pivot][col]) > 1e-9 else { return nil }
            m.swapAt(col, pivot)
            for r in 0..<n where r != col {
                let f = m[r][col] / m[col][col]
                for c in col...n { m[r][c] -= f * m[col][c] }
            }
        }
        return (0..<n).map { m[$0][n] / m[$0][$0] }
    }
}

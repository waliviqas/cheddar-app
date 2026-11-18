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

        // That clean-up lines one corner up exactly and pushes the rest of the error into "up", so it's only a first
        // guess. Nudge the phone's spot and aim until all 4 corners land as close to their taps as possible.
        let (toCamera, position) = Self.bestFit(toCamera: simd_double3x3(columns: (x, y, z)),
                                                position: -(simd_double3x3(columns: (x, y, z)).transpose * corner),
                                                points: onNet.map { SIMD3($0.x, 0, $0.y) }, seen: seen)
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

    // Check and adjust, 15 times: put the net's corners into the picture from the current guess, measure how far
    // each lands from its tap, and move the guess (3 numbers of aim, 3 of position) the way that shrinks those misses.
    private static func bestFit(toCamera r0: simd_double3x3, position t0: SIMD3<Double>,
                                points: [SIMD3<Double>], seen: [SIMD2<Double>]) -> (simd_double3x3, SIMD3<Double>) {
        func misses(_ r: simd_double3x3, _ t: SIMD3<Double>) -> [Double] {
            zip(points, seen).flatMap { p, s -> [Double] in
                let c = r * (p - t)
                return [c.x / c.z - s.x, c.y / c.z - s.y]
            }
        }
        func moved(_ r: simd_double3x3, _ t: SIMD3<Double>, by d: [Double]) -> (simd_double3x3, SIMD3<Double>) {
            (rotation(SIMD3(d[0], d[1], d[2])) * r, t + SIMD3(d[3], d[4], d[5]))
        }
        func size(_ e: [Double]) -> Double { e.reduce(0) { $0 + $1 * $1 } }

        var (r, t) = (r0, t0)
        var cost = size(misses(r, t)), damping = 1e-3
        let tiny = [1e-6, 1e-6, 1e-6, 1e-3, 1e-3, 1e-3]
        for _ in 0..<15 {
            let e = misses(r, t)
            // How each miss changes when each of the 6 numbers moves a tiny bit.
            let slopes = (0..<6).map { k -> [Double] in
                var d = [Double](repeating: 0, count: 6); d[k] = tiny[k]
                let (r2, t2) = moved(r, t, by: d)
                return zip(misses(r2, t2), e).map { ($0 - $1) / tiny[k] }
            }
            var rows = [[Double]](repeating: [Double](repeating: 0, count: 7), count: 6)
            for i in 0..<6 {
                for j in 0..<6 { rows[i][j] = zip(slopes[i], slopes[j]).reduce(0) { $0 + $1.0 * $1.1 } }
                rows[i][i] *= 1 + damping
                rows[i][6] = -zip(slopes[i], e).reduce(0) { $0 + $1.0 * $1.1 }
            }
            guard let d = solve(rows, size: 6) else { break }
            let (r2, t2) = moved(r, t, by: d)
            let newCost = size(misses(r2, t2))
            if newCost < cost { (r, t, cost) = (r2, t2, newCost); damping /= 10 } else { damping *= 10 }
        }
        return (r, t)
    }

    // A turn by the angle and around the axis of w (radians).
    private static func rotation(_ w: SIMD3<Double>) -> simd_double3x3 {
        let angle = simd_length(w)
        guard angle > 0 else { return matrix_identity_double3x3 }
        return simd_double3x3(simd_quatd(angle: angle, axis: w / angle))
    }

    // Plain row-by-row elimination for n equations, n unknowns (last column is the right-hand side).
    private static func solve(_ input: [[Double]], size n: Int = 8) -> [Double]? {
        var m = input
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

import simd

typealias Vec3 = SIMD3<Double>

/*
This class's only job is: work out where the phone is and which way it's aimed, from the net's 4 inside corners.

It finds the one phone spot and aim that would make a 6×4 ft net land on the 4 corners.
Inches: x runs along the goal line from the post on the picture's left, y runs out toward the shooter, z runs up from the floor.
*/
public struct CameraPose {
    private static let width = 72.0, height = 48.0, maxMissShare = 0.015
    private static let net = [Vec3(0, 0, height), Vec3(width, 0, height), Vec3(width, 0, 0), Vec3(0, 0, 0)]

    let position: Vec3
    let toCamera: simd_double3x3
    let lens: Lens
    var cornerMissPx = 0.0

    init(position: Vec3, toCamera: simd_double3x3, lens: Lens) {
        self.position = position
        self.toCamera = toCamera
        self.lens = lens
    }

    // Corners go top-left, top-right, bottom-right, bottom-left. No answer means they can't be a 6×4 net seen from above the floor.
    init?(corners: [Vec2], lens: Lens) {
        guard corners.count == 4, let start = Self.firstGuess(corners, lens) else { return nil }
        func adjusted(_ change: [Double]) -> CameraPose {
            CameraPose(position: start.position + Vec3(change[3], change[4], change[5]),
                       toCamera: Self.turn(Vec3(change[0], change[1], change[2])) * start.toCamera, lens: lens)
        }
        let (change, _) = Solver.leastSquares([Double](repeating: 0, count: 6), steps: [1e-7, 1e-7, 1e-7, 1e-4, 1e-4, 1e-4]) { change in
            let pose = adjusted(change)
            return zip(Self.net, corners).flatMap { spot, corner in
                let miss = pose.pixel(of: spot) - corner
                return [miss.x, miss.y]
            }
        }
        let best = adjusted(change)
        let miss = (zip(Self.net, corners).map { simd_distance_squared(best.pixel(of: $0), $1) }.reduce(0, +) / 4).squareRoot()
        let tallestPost = max(simd_distance(corners[0], corners[3]), simd_distance(corners[1], corners[2]))
        guard best.position.y > 0, best.position.z > 0, miss <= tallestPost * Self.maxMissShare else { return nil }
        self = best
        cornerMissPx = miss
    }

    func pixel(of spot: Vec3) -> Vec2 {
        let seen = toCamera * (spot - position)
        return Vec2(lens.centerX + lens.zoom * seen.x / seen.z, lens.centerY + lens.zoom * seen.y / seen.z)
    }

    // The direction from the phone through a pixel, 1 inch long.
    func ray(_ pixel: Vec2) -> Vec3 {
        simd_normalize(toCamera.transpose * Vec3((pixel.x - lens.centerX) / lens.zoom, (pixel.y - lens.centerY) / lens.zoom, 1))
    }

    func point(at pixel: Vec2, height: Double) -> Vec3 {
        let direction = ray(pixel)
        return position + direction * ((height - position.z) / direction.z)
    }

    // A quick start: the stretch that maps the flat net onto the picture, squared up into a real aim.
    static func firstGuess(_ corners: [Vec2], _ lens: Lens) -> CameraPose? {
        let seen = corners.map { Vec2(($0.x - lens.centerX) / lens.zoom, ($0.y - lens.centerY) / lens.zoom) }
        let flat = [Vec2(0, height), Vec2(width, height), Vec2(width, 0), Vec2(0, 0)]
        var rows: [[Double]] = []
        for (a, b) in zip(flat, seen) {
            rows.append([a.x, a.y, 1, 0, 0, 0, -b.x * a.x, -b.x * a.y, b.x])
            rows.append([0, 0, 0, a.x, a.y, 1, -b.y * a.x, -b.y * a.y, b.y])
        }
        guard let h = Solver.solveLinear(rows) else { return nil }
        let across = Vec3(h[0], h[3], h[6]), up = Vec3(h[1], h[4], h[7])
        let origin = Vec3(h[2], h[5], 1) * 2 / (simd_length(across) + simd_length(up))
        let x = simd_normalize(across)
        let z = simd_normalize(up - simd_dot(up, x) * x)
        let toCamera = simd_double3x3(columns: (x, simd_cross(x, z), z))
        return CameraPose(position: -(toCamera.transpose * origin), toCamera: toCamera, lens: lens)
    }

    // Turns by the length of w, in radians, around w's direction.
    static func turn(_ w: Vec3) -> simd_double3x3 {
        let angle = simd_length(w)
        guard angle > 1e-15 else { return matrix_identity_double3x3 }
        return simd_double3x3(simd_quatd(angle: angle, axis: w / angle))
    }
}

public struct Lens: Sendable {
    var zoom: Double, centerX: Double, centerY: Double
}

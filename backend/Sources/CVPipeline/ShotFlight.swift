import CoreGraphics
import simd

/*
This class's only job is: work out the exact moment the whole puck is over the goal line, and where.

Net coordinates, in inches: x along the goal line from the left post, y out toward the shooter (the goal line is y = 0),
z up from the ice.
*/
public struct ShotFlight {
    public let crossingTime: Double            // seconds after the clack frame
    public let crossingSpot: SIMD2<Double>     // where the puck's middle was right then: inches across, inches up
    public let distance: Double                // inches the puck flew from where it started to that spot

    static let puckRadius = 1.5                // a puck is 3 in across
    static let maxUnseenBeforeLine = 4.0 / 240 // how long the puck can go unseen right before the line and still count

    // `path` is the puck's spot in each frame from the clack on (nil where unseen), `times` is each frame's real time
    // in seconds after the clack frame (slow-mo skips frames now and then), `start` is where it sat on the ice.
    public init?(path: [CGPoint?], times: [Double], start: SIMD3<Double>, pose: CameraPose, lens: LensInfo) {
        guard path.count == times.count, let first = times.first else { return nil }
        // The puck flies from `start` with some speed in each direction, plus a steady up-or-down pull (gravity,
        // or nothing while it slides on the ice). Each frame where we saw it pins those 4 numbers down a little;
        // solve for the 4 that best fit every frame.
        let m = pose.toCamera
        let rows = (0..<3).map { k in SIMD3(m.columns.0[k], m.columns.1[k], m.columns.2[k]) }
        let fromCamera = start - pose.position
        var ata = simd_double4x4(), atb = SIMD4<Double>()
        var seen = 0, lastSeen = 0.0
        for (i, spot) in path.enumerated() where i > 0 {
            guard let spot else { continue }
            let t = times[i] - first
            let across = (Double(spot.x) - lens.centerX) / lens.zoom, down = (Double(spot.y) - lens.centerY) / lens.zoom
            // The puck's direction from the camera has to match where it showed up in the picture: two equations per frame.
            for w in [rows[0] - across * rows[2], rows[1] - down * rows[2]] {
                let a = SIMD4(w.x * t, w.y * t, w.z * t, w.z * 0.5 * t * t)
                let b = -simd_dot(w, fromCamera)
                ata += simd_double4x4(columns: (a * a.x, a * a.y, a * a.z, a * a.w))
                atb += a * b
            }
            seen += 1
            lastSeen = t
        }
        guard seen >= 3, abs(ata.determinant) > 1e-30 else { return nil }
        let fit = ata.inverse * atb
        let velocity = SIMD3(fit.x, fit.y, fit.z), pull = fit.w

        // The whole puck is over once its middle is 1.5 in past the goal line.
        guard velocity.y < 0 else { return nil }
        let time = (-Self.puckRadius - start.y) / velocity.y
        // Only trust it if we actually saw the puck getting close; never guess a crossing far past the last sighting.
        guard time > 0, time - lastSeen <= Self.maxUnseenBeforeLine else { return nil }

        let spot = start + velocity * time + SIMD3(0, 0, 0.5 * pull * time * time)
        crossingTime = time
        crossingSpot = SIMD2(spot.x, spot.z)
        distance = simd_distance(spot, start)
    }
}

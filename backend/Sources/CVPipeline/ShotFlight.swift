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
    public let distance: Double                // inches the puck flew from where it left the stick to that spot
    public let releaseTime: Double             // seconds after the clack frame when the puck left the stick
    public let releaseMph: Double              // how fast it left the stick, from the 20 frames right after the release
    public var flightTime: Double { crossingTime - releaseTime }   // from leaving the stick to the whole puck over the line

    static let puckRadius = 1.5                // a puck is 3 in across
    static let maxUnseenBeforeLine = 4.0 / 240 // how long the puck can go unseen right before the line and still count
    static let releaseFrames = 20              // how many frames after the release the release speed is read from

    // `path` is the puck's spot in each frame from the clack on (nil where unseen), `times` is each frame's real time
    // in seconds after the clack frame (slow-mo skips frames now and then), and `releaseTime` is when the puck left the
    // stick (from ReleaseFinder), on the same clock as `times`.
    public init?(path: [CGPoint?], times: [Double], releaseTime: Double, pose: CameraPose, lens: LensInfo) {
        guard path.count == times.count, let first = times.first else { return nil }
        // The release frame is the one closest to the release time. Before it the blade was still pushing the puck,
        // so only what happens after it counts as flight.
        guard let release = times.indices.min(by: { abs(times[$0] - releaseTime) < abs(times[$1] - releaseTime) }),
              // Where it left the stick: its spot on the ice in the release frame (or the last frame before it was seen).
              let releasePixel = path[...release].last(where: { $0 != nil }) ?? nil,
              let onIce = FloorSpot(pose: pose, lens: lens).spot(at: releasePixel)
        else { return nil }
        let start = SIMD3(onIce.x, onIce.y, 0)
        let launch = times[release] - first

        // The whole way to the net: where and when it crosses.
        guard let trip = Self.fit(path, times, after: release, upTo: path.count - 1, start: start, pose: pose, lens: lens) else { return nil }
        let velocity = trip.velocity, pull = trip.pull, lastSeen = trip.lastSeen
        // Just the frames right after the release: how fast it left the stick, before it has a chance to slow down.
        guard let off = Self.fit(path, times, after: release, upTo: min(path.count - 1, release + Self.releaseFrames), start: start, pose: pose, lens: lens)
        else { return nil }
        releaseMph = simd_length(off.velocity) / 17.6   // 1 mph = 17.6 inches per second

        // The whole puck is over once its middle is 1.5 in past the goal line.
        guard velocity.y < 0 else { return nil }
        let time = (-Self.puckRadius - start.y) / velocity.y
        // Only trust it if we actually saw the puck getting close; never guess a crossing far past the last sighting.
        guard time > 0, time - lastSeen <= Self.maxUnseenBeforeLine else { return nil }

        let spot = start + velocity * time + SIMD3(0, 0, 0.5 * pull * time * time)
        crossingTime = launch + time
        self.releaseTime = launch
        crossingSpot = SIMD2(spot.x, spot.z)
        distance = simd_distance(spot, start)
    }

    // The puck flies from `start` with some speed in each direction, plus a steady up-or-down pull (gravity, or nothing
    // while it slides on the ice). Each frame after the release (up to `last`) where we saw it pins those 4 numbers down
    // a little; solve for the 4 that best fit those frames. Time counts from the release frame.
    private static func fit(_ path: [CGPoint?], _ times: [Double], after release: Int, upTo last: Int, start: SIMD3<Double>,
                            pose: CameraPose, lens: LensInfo) -> (velocity: SIMD3<Double>, pull: Double, lastSeen: Double)? {
        guard last > release else { return nil }
        let m = pose.toCamera
        let rows = (0..<3).map { k in SIMD3(m.columns.0[k], m.columns.1[k], m.columns.2[k]) }
        let fromCamera = start - pose.position
        var ata = simd_double4x4(), atb = SIMD4<Double>()
        var seen = 0, lastSeen = 0.0
        for i in (release + 1)...last {
            guard let spot = path[i] else { continue }
            let t = times[i] - times[release]
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
        return (SIMD3(fit.x, fit.y, fit.z), fit.w, lastSeen)
    }
}

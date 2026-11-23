import Foundation
import simd

/*
This class's only job is: read every shot in a video, from the video and the player's 4 net taps.

It moves the taps onto the net, places the phone, searches a strip of the picture worked out from the net,
and keeps only readings whose dot lands on the net.
*/
// One shot in the video: when it left the stick, in seconds into the video, its speed, and where its middle reached the
// net, in inches across from the left post and up from the ground.
public struct ShotReading: Sendable {
    public let releaseTime: Double, mph: Double, hit: Vec2, slid: Bool
}

public enum ShotReader {
    private static let nov16PostHeight = 316.5, maxFitMissPx = 3.0, netSideColumns = 150..<1910
    private static let shotStarts: [Double] = [96, 144, 192, 216]
    static let netFrameTime = 1.0  // seconds in, past the wobble from tapping record

    // No answer means the taps can't be a net.
    public static func read(_ clip: URL, taps: [Vec2], lens: Lens) async throws -> [ShotReading]? {
        var corners = taps
        if let still = try await Clip.picture(clip, at: netFrameTime), let better = NetCorners.refine(taps, picture: still) {
            corners = better
        }
        guard let pose = CameraPose(corners: corners, lens: lens) else { return nil }
        let frames = try await scan(clip, lane: lane(corners: corners, pose: pose))
        return shots(in: frames, pose: pose, scale: netScale(corners))
    }

    static func scan(_ clip: URL, lane: (rows: Range<Int>, columns: Range<Int>)) async throws -> [SpotFrame] {
        var dark = TwoFramesBack(rows: lane.rows, columns: lane.columns)
        try await Clip.eachFrame(clip) { buffer, time in dark.add(buffer, time: time) }
        return dark.frames
    }

    static func shots(in frames: [SpotFrame], pose: CameraPose, scale: Double) -> [ShotReading] {
        let direction = towardNet(pose)
        return ShotFinder.flights(frames, towardNet: direction).compactMap { flight in
            guard let track = PuckTrack.exact(flight, frames: frames, towardNet: direction), let fit = ShotFit.read(track, pose: pose),
                  keeps(fit, scale: scale) else { return nil }
            return ShotReading(releaseTime: fit.releaseTime, mph: fit.mph, hit: fit.hit, slid: fit.slid)
        }
    }

    // A closer phone sees a bigger, rougher puck, so the fit limit grows with the net but never shrinks.
    static func keeps(_ fit: ShotFitResult, scale: Double) -> Bool {
        fit.fitMissPx <= maxFitMissPx * max(1, scale) && (5.0...130).contains(fit.mph)
            && (0.0...72).contains(fit.hit.x) && (0.0...48).contains(fit.hit.y)
    }

    // From a little above the crossbar to a little below where shots 8 to 18 ft out start, on the net's side of the picture.
    static func lane(corners: [Vec2], pose: CameraPose) -> (rows: Range<Int>, columns: Range<Int>) {
        let post = netScale(corners) * nov16PostHeight
        let top = min(corners[0].y, corners[1].y) - 0.095 * post
        var bottom = max(corners[2].y, corners[3].y) + 0.045 * post
        for out in shotStarts where (pose.toCamera * (Vec3(36, out, 0) - pose.position)).z > 12 {
            bottom = max(bottom, pose.pixel(of: Vec3(36, out, 0)).y + 0.045 * post)
        }
        let netOnRight = corners.map(\.x).reduce(0, +) / 4 > pose.lens.centerX
        let columns = netOnRight ? netSideColumns : (1920 - netSideColumns.upperBound)..<(1920 - netSideColumns.lowerBound)
        return (max(0, Int(top))..<min(1080, Int(bottom) + 1), columns)
    }

    // +1 when shots cross the picture left to right.
    static func towardNet(_ pose: CameraPose) -> Double {
        pose.pixel(of: Vec3(36, 0, 24)).x > pose.pixel(of: Vec3(36, 120, 0.75)).x ? 1 : -1
    }

    // How tall the posts look compared with Wali's Nov 16 setup.
    static func netScale(_ corners: [Vec2]) -> Double {
        (simd_distance(corners[0], corners[3]) + simd_distance(corners[1], corners[2])) / 2 / nov16PostHeight
    }
}

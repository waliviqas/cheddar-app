import CoreGraphics
import Foundation

/*
This struct's only job is: Video, setup tap, and shot time in, shot speed in mph out.
*/
public struct RinkShotReader {
    public init() {}

    // Calibrates on the tapped puck, cuts out the shot, follows the puck with the trained model, and reads the speed.
    // The tap is in pixels measured from the top-left, like a tap on the screen.
    public func mph(video: URL, tappedAt tap: CGPoint, tapSeconds: Double, shotStartSeconds: Double) async throws -> Double? {
        let extractor = VideoFrameExtractor()
        guard let tapFrame = try await extractor.frames(from: video, between: tapSeconds, and: tapSeconds + 0.05).first?.image
        else { return nil }
        let spot = CGPoint(x: tap.x, y: Double(tapFrame.height) - tap.y)
        guard let pixelsPerInch = PuckRuler().pixelsPerInch(in: tapFrame, tappedAt: spot) else { return nil }

        let shot = try await extractor.frames(from: video, between: shotStartSeconds - 0.05, and: shotStartSeconds + 0.35)
        let times = shot.map { $0.seconds }
        let detector = PuckDetector()
        let found = shot.map { detector.pucks(in: $0.image).map { CGPoint(x: $0.midX, y: $0.midY) } }
        let path = fastPart(of: shotPath(through: found, startingNear: spot), times: times)
        return SpeedCalculator().mph(path: path, times: times, pixelsPerFoot: pixelsPerInch * 12)
    }

    // Follows every puck at once. Each frame, the closest pairs of "where a puck should be next" and "where a puck was
    // found" are matched first, so two pucks side by side keep their own paths. A path never jumps more than 150px and
    // ends after 3 frames without a match. The shot is the path starting near the tap that travels farthest.
    private func shotPath(through found: [[CGPoint]], startingNear spot: CGPoint) -> [CGPoint?] {
        struct Track {
            var points: [Int: CGPoint]
            var last: CGPoint
            var previous: CGPoint
            var misses = 0
        }
        var tracks: [Track] = []
        for (frame, points) in found.enumerated() {
            let live = tracks.indices.filter { tracks[$0].misses < 3 }
            var pairs: [(distance: Double, track: Int, point: Int)] = []
            for t in live {
                let expected = CGPoint(x: 2 * tracks[t].last.x - tracks[t].previous.x, y: 2 * tracks[t].last.y - tracks[t].previous.y)
                for (p, point) in points.enumerated() {
                    let d = hypot(point.x - expected.x, point.y - expected.y)
                    if d <= 150 { pairs.append((d, t, p)) }
                }
            }
            var usedTracks = Set<Int>(), usedPoints = Set<Int>()
            for pair in pairs.sorted(by: { $0.distance < $1.distance })
            where !usedTracks.contains(pair.track) && !usedPoints.contains(pair.point) {
                usedTracks.insert(pair.track)
                usedPoints.insert(pair.point)
                tracks[pair.track].points[frame] = points[pair.point]
                tracks[pair.track].previous = tracks[pair.track].last
                tracks[pair.track].last = points[pair.point]
                tracks[pair.track].misses = 0
            }
            for t in live where !usedTracks.contains(t) { tracks[t].misses += 1 }
            for (p, point) in points.enumerated() where !usedPoints.contains(p) {
                tracks.append(Track(points: [frame: point], last: point, previous: point))
            }
        }

        let candidates = tracks.filter { track in
            guard let start = track.points.min(by: { $0.key < $1.key }) else { return false }
            return hypot(start.value.x - spot.x, start.value.y - spot.y) <= 100
        }
        func travel(_ track: Track) -> Double {
            guard let first = track.points.min(by: { $0.key < $1.key })?.value else { return 0 }
            return hypot(track.last.x - first.x, track.last.y - first.y)
        }
        guard let shot = candidates.max(by: { travel($0) < travel($1) }) else { return [] }
        return found.indices.map { shot.points[$0] }
    }

    // Keeps only the frames where the puck moves at least 40% of its top speed, so the slow drag on the stick
    // and anything after it stops don't pull the speed down.
    private func fastPart(of path: [CGPoint?], times: [Double]) -> [CGPoint?] {
        let seen = path.indices.filter { path[$0] != nil }
        let steps = zip(seen, seen.dropFirst()).map { a, b in
            (a: a, b: b, speed: hypot(path[b]!.x - path[a]!.x, path[b]!.y - path[a]!.y) / (times[b] - times[a]))
        }
        guard let top = steps.map({ $0.speed }).max() else { return path }
        let fast = steps.filter { $0.speed >= 0.4 * top }
        guard let start = fast.first?.a, let end = fast.last?.b else { return path }
        return path.indices.map { $0 >= start && $0 <= end ? path[$0] : nil }
    }
}

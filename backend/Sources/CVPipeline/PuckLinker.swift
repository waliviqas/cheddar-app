import CoreGraphics
import Foundation

/*
This class's only job is: follow the shot puck from the stick, frame by frame, through every puck-looking box the
puck model saw, ignoring look-alikes that never move.
*/
public struct PuckLinker {
    private let startReach: CGFloat = 40      // how far from the clack spot the puck can be in the first frame
    private let firstStep: CGFloat = 60       // how far it can move in 1/240 s, before we know its speed
    private let tick = 1.0 / 240              // one slow-mo frame, when the video doesn't skip any
    private let maxUnseen = 4.0 / 240         // how long the puck can go unseen (blur) before we call it gone

    public init() {}

    // `frames` are the puck model's boxes for each frame, starting at the clack frame (y down), and `times` is each
    // frame's real time in seconds (slow-mo video skips frames now and then, so they aren't evenly spaced).
    // Returns the shot puck's spot in each frame, or nil where it wasn't seen.
    public func path(from start: CGPoint, through frames: [[CGRect]], times: [Double]) -> [CGPoint?] {
        let spots = frames.map { $0.map { CGPoint(x: $0.midX, y: $0.midY) } }
        let moving = spots.indices.map { i in spots[i].filter { !isStill($0, at: i, in: spots) } }

        var path = [CGPoint?](repeating: nil, count: frames.count)
        guard frames.count == times.count, let first = nearest(to: start, in: moving.first ?? [], within: startReach) else { return path }
        path[0] = first

        var last = first, lastTime = times[0]
        var velocity: CGPoint? = nil     // pixels per second, once we've seen it twice
        for i in 1..<frames.count {
            let gap = times[i] - lastTime
            // A skipped video frame isn't the puck going unseen; only give up after real frames go by without it.
            guard gap <= maxUnseen + 2 * tick + 1e-6 || hasRecentSighting(lastTime, times, i) else { break }
            let ticks = CGFloat(gap / tick)
            let guess = CGPoint(x: last.x + (velocity?.x ?? 0) * gap, y: last.y + (velocity?.y ?? 0) * gap)
            let speedPerTick = velocity.map { hypot($0.x, $0.y) * tick } ?? 0
            let reach = velocity == nil ? firstStep * ticks : max(15, speedPerTick * 0.5) * ticks
            guard let found = nearest(to: guess, in: moving[i], within: reach) else { continue }
            velocity = CGPoint(x: (found.x - last.x) / gap, y: (found.y - last.y) / gap)
            path[i] = found
            last = found
            lastTime = times[i]
        }
        return path
    }

    // Whether fewer than 4 real frames have gone by since the last sighting (frames the video skipped don't count).
    private func hasRecentSighting(_ lastTime: Double, _ times: [Double], _ i: Int) -> Bool {
        times[..<i].filter { $0 > lastTime }.count < 4
    }

    // A spot that's in the same place (within 3 px) in the frame before and the frame after isn't moving,
    // so it can't be the shot: an old puck in the net, a dark spot on the boards.
    private func isStill(_ spot: CGPoint, at i: Int, in spots: [[CGPoint]]) -> Bool {
        func hasTwin(_ j: Int) -> Bool { spots.indices.contains(j) && spots[j].contains { hypot($0.x - spot.x, $0.y - spot.y) <= 3 } }
        return hasTwin(i - 1) && hasTwin(i + 1)
    }

    private func nearest(to target: CGPoint, in spots: [CGPoint], within reach: CGFloat) -> CGPoint? {
        spots
            .filter { hypot($0.x - target.x, $0.y - target.y) <= reach }
            .min { hypot($0.x - target.x, $0.y - target.y) < hypot($1.x - target.x, $1.y - target.y) }
    }
}

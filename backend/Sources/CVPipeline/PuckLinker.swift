import CoreGraphics
import Foundation

/*
This class's only job is: follow the shot puck from the stick, frame by frame, through every puck-looking box the
puck model saw, ignoring look-alikes that never move.
*/
public struct PuckLinker {
    private let startReach: CGFloat = 40   // how far from the clack spot the puck can be in the first frame
    private let firstStep: CGFloat = 60    // how far it can move in the next frame, before we know its speed
    private let maxMissed = 3              // frames the puck can go unseen (blur) before we call it gone

    public init() {}

    // `frames` are the puck model's boxes for each frame, starting at the clack frame (y down).
    // Returns the shot puck's spot in each frame, or nil where it wasn't seen.
    public func path(from start: CGPoint, through frames: [[CGRect]]) -> [CGPoint?] {
        let spots = frames.map { $0.map { CGPoint(x: $0.midX, y: $0.midY) } }
        let moving = spots.indices.map { i in spots[i].filter { !isStill($0, at: i, in: spots) } }

        var path = [CGPoint?](repeating: nil, count: frames.count)
        guard let first = nearest(to: start, in: moving.first ?? [], within: startReach) else { return path }
        path[0] = first

        var last = first, lastFrame = 0
        var velocity: CGPoint? = nil     // pixels per frame, once we've seen it twice
        for i in 1..<frames.count {
            let gap = CGFloat(i - lastFrame)
            guard i - lastFrame <= maxMissed + 1 else { break }
            let guess = CGPoint(x: last.x + (velocity?.x ?? 0) * gap, y: last.y + (velocity?.y ?? 0) * gap)
            let speed = velocity.map { hypot($0.x, $0.y) } ?? 0
            let reach = velocity == nil ? firstStep * gap : max(15, speed * 0.5) * gap
            guard let found = nearest(to: guess, in: moving[i], within: reach) else { continue }
            velocity = CGPoint(x: (found.x - last.x) / gap, y: (found.y - last.y) / gap)
            path[i] = found
            last = found
            lastFrame = i
        }
        return path
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

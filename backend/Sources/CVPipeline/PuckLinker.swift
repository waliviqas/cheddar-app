import CoreGraphics
import Foundation

/*
This class's only job is: follow the shot puck from the stick, frame by frame, asking the puck model to look only where
the puck should be, and ignoring look-alikes that never move.
*/
public struct PuckLinker {
    private let startReach: CGFloat = 40      // how far from the clack spot the puck can be in the first frame
    private let firstStep: CGFloat = 60       // how far it can move in 1/240 s, before we know its speed
    private let tick = 1.0 / 240              // one slow-mo frame, when the video doesn't skip any
    private let maxUnseen = 4.0 / 240         // how long the puck can go unseen (blur) before we call it gone
    private let stillWiggle: CGFloat = 6      // how much a resting puck's box can jitter and still count as sitting there
    private let takeoffReach: CGFloat = 250   // how far it can jump in 1/240 s the moment it leaves the stick

    public init() {}

    // `times` is each frame's real time in seconds from the clack frame on (slow-mo video skips frames now and then, so
    // they aren't evenly spaced). `look` asks the puck model for the puck boxes in one frame, only in the 320px square
    // around a spot (pixels from the top-left, y down), so only the area where the puck should be gets searched.
    // Returns the shot puck's spot in each frame, or nil where it wasn't seen.
    public func path(from start: CGPoint, times: [Double], lookingNear look: @escaping (_ frame: Int, _ around: CGPoint) -> [CGRect]) -> [CGPoint?] {
        let seen = Looks(look, frames: times.count)
        var path = [CGPoint?](repeating: nil, count: times.count)
        guard !times.isEmpty, let first = nearest(to: start, in: seen.spots(in: 0, near: start), within: startReach) else { return path }
        path[0] = first

        var last = first, lastTime = times[0]
        var velocity: CGPoint? = nil     // pixels per second, once we've seen it twice
        var launched = false             // the puck often sits at the blade for a few frames after the clack
        for i in 1..<times.count {
            if !launched {
                let around = seen.spots(in: i, near: first)
                // Still sitting at the blade? Then it's the same puck, even though it isn't moving.
                if let sitting = nearest(to: first, in: around, within: stillWiggle) {
                    path[i] = sitting
                    last = sitting
                    lastTime = times[i]
                    continue
                }
                // It just left the stick: it can jump far in one frame, so look wide (moving things only).
                let ticks = CGFloat((times[i] - lastTime) / tick)
                if let off = nearest(to: first, in: moving(around, at: i, seen), within: takeoffReach * ticks) {
                    // That first jump says little about its real speed, so start fresh from here.
                    velocity = nil
                    path[i] = off
                    last = off
                    lastTime = times[i]
                    launched = true
                }
                continue
            }
            let gap = times[i] - lastTime
            // A skipped video frame isn't the puck going unseen; only give up after real frames go by without it.
            guard gap <= maxUnseen + 2 * tick + 1e-6 || hasRecentSighting(lastTime, times, i) else { break }
            let ticks = CGFloat(gap / tick)
            let drift: CGPoint = velocity ?? .zero
            let guess = CGPoint(x: last.x + drift.x * CGFloat(gap), y: last.y + drift.y * CGFloat(gap))
            let candidates = moving(seen.spots(in: i, near: guess), at: i, seen)
            let speedPerTick = velocity.map { hypot($0.x, $0.y) * tick } ?? 0
            let reach = velocity == nil ? firstStep * ticks : max(15, speedPerTick * 0.5) * ticks
            // Off the blade the puck keeps speeding up, so if it isn't near the guess, also accept a box further along
            // the same direction (up to 4× as far, at most 30° off course).
            guard let found = nearest(to: guess, in: candidates, within: reach)
                ?? velocity.flatMap({ speedingUp(from: last, heading: $0, over: gap, in: candidates) }) else { continue }
            let step = CGPoint(x: (found.x - last.x) / gap, y: (found.y - last.y) / gap)
            // Blend with the last speed so one wobbly box doesn't throw off the next guess.
            velocity = velocity.map { CGPoint(x: ($0.x + step.x) / 2, y: ($0.y + step.y) / 2) } ?? step
            path[i] = found
            last = found
            lastTime = times[i]
        }
        return path
    }

    // Remembers what the puck model saw in each square it searched, so the same area isn't searched twice.
    private final class Looks {
        private let look: (Int, CGPoint) -> [CGRect]
        private let frames: Int
        private var squares: [Int: [(center: CGPoint, spots: [CGPoint])]] = [:]
        init(_ look: @escaping (Int, CGPoint) -> [CGRect], frames: Int) { self.look = look; self.frames = frames }

        // The puck spots near `p` in one frame. Reuses a square already searched if `p` sits well inside it
        // (at least 60 px from its edge), otherwise searches the square around `p`.
        func spots(in frame: Int, near p: CGPoint) -> [CGPoint] {
            guard (0..<frames).contains(frame) else { return [] }
            if let done = squares[frame]?.first(where: { abs($0.center.x - p.x) <= 100 && abs($0.center.y - p.y) <= 100 }) {
                return done.spots
            }
            let spots = look(frame, p).map { CGPoint(x: $0.midX, y: $0.midY) }
            squares[frame, default: []].append((p, spots))
            return spots
        }
    }

    // Drops the spots that sit still: in the same place (within 3 px) in the frame before and the frame after, so they
    // can't be the shot (an old puck in the net, a dark spot on the boards, tape on the floor).
    private func moving(_ spots: [CGPoint], at i: Int, _ seen: Looks) -> [CGPoint] {
        func hasTwin(_ spot: CGPoint, in frame: Int) -> Bool {
            seen.spots(in: frame, near: spot).contains { hypot($0.x - spot.x, $0.y - spot.y) <= 3 }
        }
        return spots.filter { spot in !(i > 0 && hasTwin(spot, in: i - 1) && hasTwin(spot, in: i + 1)) }
    }

    // The box that looks like the puck kept going the same way but faster (or a bit slower): between 0.3× and 4× as far
    // as expected, and within 30° of its heading. Picks the one most on course.
    private func speedingUp(from last: CGPoint, heading v: CGPoint, over gap: Double, in spots: [CGPoint]) -> CGPoint? {
        let expected = hypot(v.x, v.y) * gap
        guard expected > 0 else { return nil }
        let dir = CGPoint(x: v.x / hypot(v.x, v.y), y: v.y / hypot(v.x, v.y))
        func angle(_ p: CGPoint) -> CGFloat {
            let d = CGPoint(x: p.x - last.x, y: p.y - last.y), n = hypot(d.x, d.y)
            return n > 0 ? acos(max(-1, min(1, (d.x * dir.x + d.y * dir.y) / n))) : .pi
        }
        return spots
            .filter { p in
                let n = hypot(p.x - last.x, p.y - last.y)
                return n >= 0.3 * expected && n <= 4 * expected && angle(p) <= .pi / 6
            }
            .min { angle($0) < angle($1) }
    }

    // Whether fewer than 4 real frames have gone by since the last sighting (frames the video skipped don't count).
    private func hasRecentSighting(_ lastTime: Double, _ times: [Double], _ i: Int) -> Bool {
        times[..<i].filter { $0 > lastTime }.count < 4
    }

    private func nearest(to target: CGPoint, in spots: [CGPoint], within reach: CGFloat) -> CGPoint? {
        spots
            .filter { hypot($0.x - target.x, $0.y - target.y) <= reach }
            .min { hypot($0.x - target.x, $0.y - target.y) < hypot($1.x - target.x, $1.y - target.y) }
    }
}

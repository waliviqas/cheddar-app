import CoreGraphics

/*
This struct's only job is: Puck catches over time in, the shot's speed in pixels per second out.
*/
public struct FlightLine {
    public init() {}

    // Reads the speed from the straight line the shot's catches make.
    public func pixelsPerSecond(frames: [(seconds: Double, points: [CGPoint])]) -> Double? {
        let best = flight(frames: frames).map { (t: $0.seconds, p: $0.point) }
        guard !best.isEmpty else { return nil }

        let meanT = best.map { $0.t }.reduce(0, +) / Double(best.count)
        let spread = best.map { ($0.t - meanT) * ($0.t - meanT) }.reduce(0, +)
        let vx = best.map { ($0.t - meanT) * $0.p.x }.reduce(0, +) / spread
        let vy = best.map { ($0.t - meanT) * $0.p.y }.reduce(0, +) / spread
        return hypot(vx, vy)
    }

    // The shot's catches: the largest group that sits on one straight line at a steady speed, at most one per frame.
    // Anything slower than 500px a second, like a speck wobbling in place, can't be the shot. Empty when there's no shot.
    public func flight(frames: [(seconds: Double, points: [CGPoint])]) -> [(seconds: Double, point: CGPoint)] {
        let catches = frames.flatMap { frame in frame.points.map { (t: frame.seconds, p: $0) } }
        var best: [(t: Double, p: CGPoint)] = []
        for (i, a) in catches.enumerated() {
            for b in catches[(i + 1)..<catches.count] where b.t != a.t {
                let vx = (b.p.x - a.p.x) / (b.t - a.t)
                let vy = (b.p.y - a.p.y) / (b.t - a.t)
                guard hypot(vx, vy) >= 500 else { continue }
                let onLine = catchesOnLine(catches, through: a, vx: vx, vy: vy)
                if onLine.count > best.count { best = onLine }
            }
        }
        guard best.count >= 3 else { return [] }
        return best.sorted { $0.t < $1.t }.map { (seconds: $0.t, point: $0.p) }
    }

    // The catches within 12px of where the line says the puck should be at their time, keeping the closest one per frame.
    private func catchesOnLine(_ catches: [(t: Double, p: CGPoint)], through a: (t: Double, p: CGPoint),
                               vx: Double, vy: Double) -> [(t: Double, p: CGPoint)] {
        var closest: [Double: (c: (t: Double, p: CGPoint), off: Double)] = [:]
        for c in catches {
            let off = hypot(c.p.x - (a.p.x + vx * (c.t - a.t)), c.p.y - (a.p.y + vy * (c.t - a.t)))
            if off <= 12, off < closest[c.t]?.off ?? .infinity {
                closest[c.t] = (c, off)
            }
        }
        return closest.values.map { $0.c }
    }
}

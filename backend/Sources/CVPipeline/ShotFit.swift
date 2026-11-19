import simd

/*
This class's only job is: turn one shot's puck pixels into its speed off the stick and where it crossed the goal line.

The puck leaves the floor 2 frames before it's first seen clear of the stick, then flies with a steady pull down
(gravity plus lift) and air drag. Inches: x along the goal line from the left post, y out toward the shooter, z up.
*/
struct ShotFitResult {
    let mph: Double, releaseTime: Double, hit: Vec2, slid: Bool, fitMissPx: Double
}

enum ShotFit {
    static let drag = 1.3e-4
    private static let dotDrag = 2.5e-4, releaseLead = 2.0 / 240, dotLead = 4.0 / 240
    private static let floorHeight = 0.75, slideHeight = 0.5, maxSlideRise = 1.0, inchesPerSecondInMph = 17.6

    struct FittedPath {
        let velocity: Vec3, cross: Vec3, missPx: Double, lineMph: Double, rise: Double
    }

    static func read(_ track: [TrackPoint], pose: CameraPose) -> ShotFitResult? {
        guard track.count >= 10, let shot = settled(track, pose: pose, drag: drag, lead: releaseLead) else { return nil }
        if shot.rise < maxSlideRise, let slide = slide(track, pose: pose) {
            return ShotFitResult(mph: slide.mph, releaseTime: track[0].t, hit: Vec2(slide.hit.x, slide.hit.z), slid: true, fitMissPx: shot.missPx)
        }
        // Speed keeps its own fit. The dot uses real pucks' drag and a later first clear frame, which put more real goals in the net.
        let dot = settled(track, pose: pose, drag: dotDrag, lead: dotLead) ?? shot
        return ShotFitResult(mph: shot.lineMph, releaseTime: track[0].t - releaseLead, hit: Vec2(dot.cross.x, dot.cross.z),
                             slid: false, fitMissPx: shot.missPx)
    }

    // The puck climbs between leaving the stick and its first clear frame, so the start height is refit a few times.
    private static func settled(_ track: [TrackPoint], pose: CameraPose, drag k: Double, lead: Double) -> FittedPath? {
        var height = floorHeight, best: FittedPath?
        for _ in 0..<4 {
            guard let path = flight(track, pose: pose, startHeight: height, drag: k) else { return best }
            best = path
            height = floorHeight + max(path.velocity.z, 0) * lead
        }
        return flight(track, pose: pose, startHeight: height, drag: k) ?? best
    }

    static func flight(_ track: [TrackPoint], pose: CameraPose, startHeight: Double, drag k: Double = drag) -> FittedPath? {
        let t0 = track[0].t
        let start = pose.point(at: pixel(track[0]), height: startHeight)
        var used = track, velocity = Vec3.zero, pull = -386.09, miss = 0.0
        var cross: (t: Double, p: Vec3)?
        for round in 0..<3 {
            let times = used.map { $0.t - t0 }
            if round == 0 {
                let far = pose.position + pose.ray(pixel(used.last!)) * (simd_length(start - pose.position) + 10)
                velocity = (far - start) / times.last!
            }
            let seen = used
            let (fit, _) = Solver.leastSquares([velocity.x, velocity.y, velocity.z, pull], steps: [1e-2, 1e-2, 1e-2, 1e-2]) { p in
                zip(simulate(start, Vec3(p[0], p[1], p[2]), pull: p[3], at: times, drag: k), seen).flatMap { spot, point -> [Double] in
                    let off = pose.pixel(of: spot) - pixel(point)
                    return [off.x, off.y]
                }
            }
            velocity = Vec3(fit[0], fit[1], fit[2])
            pull = fit[3]
            let path = simulate(start, velocity, pull: pull, at: times, drag: k)
            miss = (zip(path, used).map { simd_distance_squared(pose.pixel(of: $0), pixel($1)) }.reduce(0, +) / Double(used.count)).squareRoot()
            cross = crossing(start, velocity, pull, t0: t0, until: times.last! + 0.3, drag: k)
            guard let c = cross else { break }
            let kept = track.filter { $0.t <= c.t + 2.5 / 240 }
            if kept.count == used.count { break }
            used = kept
            if used.count < 10 { return nil }
        }
        guard let c = cross else { return nil }
        // Speed along the straight line from the start to the crossing, with every frame's sight line placed on it.
        let line = simd_normalize(c.p - start)
        let onLine = track.filter { $0.t <= c.t + 1e-6 }
        let along = onLine.map { lineSpot(start, line, pose.position, pose.ray(pixel($0))) }
        let fit = Solver.polyfit(onLine.map { $0.t - t0 }, along, degree: 1)
        let span = (along.last ?? 0) - (along.first ?? 0)
        let heights = simulate(start, velocity, pull: pull, at: Array(stride(from: 0.0, through: c.t - t0, by: 1e-3)), drag: k).map(\.z)
        return FittedPath(velocity: velocity, cross: c.p, missPx: miss, lineMph: fit[1] * (1 + drag * span / 2) / inchesPerSecondInMph,
                          rise: heights.max()! - startHeight)
    }

    // A puck on the floor: every frame's spot is known exactly, so distance against time with a steady slow-down gives the speed.
    static func slide(_ track: [TrackPoint], pose: CameraPose) -> (mph: Double, crossT: Double, hit: Vec3)? {
        let spots = track.map { pose.point(at: pixel($0), height: slideHeight) }
        let direction = simd_normalize(spots.last! - spots[0])
        guard direction.y < 0 else { return nil }
        let fit = Solver.polyfit(track.map { $0.t - track[0].t }, spots.map { simd_dot($0 - spots[0], direction) }, degree: 2)
        let toLine = -spots[0].y / direction.y
        let room = fit[1] * fit[1] + 4 * fit[2] * (toLine - fit[0])
        let time = fit[2] < 0 && room > 0 ? (-fit[1] + room.squareRoot()) / (2 * fit[2]) : (toLine - fit[0]) / fit[1]
        return (fit[1] / inchesPerSecondInMph, track[0].t + time, spots[0] + direction * toLine)
    }

    // Where the puck is at each time (seconds after the start), with a steady pull down and air drag, in small midpoint steps.
    static func simulate(_ start: Vec3, _ velocity: Vec3, pull: Double, at times: [Double], drag k: Double = drag) -> [Vec3] {
        let step = 2.5e-4, down = Vec3(0, 0, pull)
        var out = [Vec3](repeating: .zero, count: times.count)
        var spot = start, speed = velocity, time = 0.0, next = 0
        while next < times.count && times[next] <= 1e-12 {
            out[next] = spot
            next += 1
        }
        while next < times.count {
            let h = min(step, times[next] - time)
            let middle = speed + 0.5 * h * (down - k * simd_length(speed) * speed)
            spot += h * middle
            speed += h * (down - k * simd_length(middle) * middle)
            time += h
            if abs(time - times[next]) < 1e-12 {
                out[next] = spot
                next += 1
            }
        }
        return out
    }

    // When and where the path reaches the goal line, looking up to `until` seconds after the start.
    static func crossing(_ start: Vec3, _ velocity: Vec3, _ pull: Double, t0: Double, until: Double, drag k: Double = drag) -> (t: Double, p: Vec3)? {
        let times = Array(stride(from: 0.0, through: until, by: 1e-4))
        let path = simulate(start, velocity, pull: pull, at: times, drag: k)
        guard let i = path.firstIndex(where: { $0.y <= 0 }), i > 0 else { return nil }
        let share = path[i - 1].y / (path[i - 1].y - path[i].y)
        return (t0 + times[i - 1] + share * 1e-4, path[i - 1] + share * (path[i] - path[i - 1]))
    }

    // How far along the line a + s·e lies the spot closest to the sight line c + q·r.
    static func lineSpot(_ a: Vec3, _ e: Vec3, _ c: Vec3, _ r: Vec3) -> Double {
        let w = a - c, b = simd_dot(e, r)
        return (b * simd_dot(r, w) - simd_dot(e, w)) / (1 - b * b)
    }

    private static func pixel(_ point: TrackPoint) -> Vec2 {
        Vec2(point.x, point.y)
    }
}

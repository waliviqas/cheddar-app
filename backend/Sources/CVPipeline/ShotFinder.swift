import Foundation

struct TrackPoint {
    let t: Double, x: Double, y: Double
}

struct Flight {
    let points: [TrackPoint]
}

/*
This class's only job is: find when each shot happens by following the dark spots from frame to frame.

Everything uses each frame's own time, so dropped frames don't cut a flight.
*/
enum ShotFinder {
    static let maxUnseen = 0.03, sameShotWindow = 0.3
    private static let pathReach = 30.0, firstJumpReach = 90.0
    static let minSpeed = 800.0, minTravel = 600.0, minSightings = 8
    static let minBumpPixels = 5000, bumpTimesTypical = 10

    static func flights(_ frames: [SpotFrame], towardNet direction: Double) -> [Flight] {
        let fastParts = link(frames).compactMap { fastPart($0, towardNet: direction) }.sorted { $0[0].t < $1[0].t }
        var shots: [[[TrackPoint]]] = []
        for part in fastParts {
            if let previous = shots.last?.last?.last, part[0].t <= previous.t + sameShotWindow {
                shots[shots.count - 1].append(part)
            } else {
                shots.append([part])
            }
        }
        return shots.map { pieces in
            Flight(points: pieces.max { (travel($0, direction), $0.count) < (travel($1, direction), $1.count) }!)
        }
    }

    static func link(_ frames: [SpotFrame]) -> [[TrackPoint]] {
        let limit = bumpLimit(in: frames)
        var following: [[TrackPoint]] = [], finished: [[TrackPoint]] = []
        for frame in frames {
            let spots = frame.changed > limit ? [] : frame.spots
            var unclaimed = [Bool](repeating: true, count: spots.count)
            for index in following.indices.sorted(by: { following[$0].count > following[$1].count }) {
                guard let spot = nearestSpot(for: following[index], at: frame.time, in: spots, unclaimed) else { continue }
                unclaimed[spot] = false
                following[index].append(TrackPoint(t: frame.time, x: spots[spot].x, y: spots[spot].y))
            }
            finished += following.filter { frame.time - $0.last!.t > maxUnseen }
            following.removeAll { frame.time - $0.last!.t > maxUnseen }
            for (index, spot) in spots.enumerated() where unclaimed[index] {
                following.append([TrackPoint(t: frame.time, x: spot.x, y: spot.y)])
            }
        }
        return finished + following
    }

    // The longest unbroken fast stretch of a path, if it could be a shot at the net.
    static func fastPart(_ path: [TrackPoint], towardNet direction: Double) -> [TrackPoint]? {
        func isFast(_ step: Int) -> Bool {
            let from = path[step], to = path[step + 1]
            return hypot(to.x - from.x, to.y - from.y) / (to.t - from.t) >= minSpeed
        }

        var longest = 0..<0, step = 0
        while step < path.count - 1 {
            guard isFast(step) else { step += 1; continue }
            var end = step + 1
            while end < path.count - 1, isFast(end) { end += 1 }
            if end - step > longest.count { longest = step..<end }
            step = end
        }
        guard !longest.isEmpty else { return nil }

        let part = Array(path[longest.lowerBound...longest.upperBound])
        return part.count >= minSightings && travel(part, direction) >= minTravel ? part : nil
    }

    // A bumped phone changes far more pixels than this clip normally does.
    private static func bumpLimit(in frames: [SpotFrame]) -> Int {
        let changed = frames.map(\.changed).sorted()
        let typical = changed.isEmpty ? 0 : changed[changed.count / 2]
        return max(minBumpPixels, bumpTimesTypical * typical)
    }

    // A path with one sighting has no speed yet, so its first jump gets a wider reach.
    static func nearestSpot(for path: [TrackPoint], at time: Double, in spots: [Spot], _ unclaimed: [Bool]) -> Int? {
        let last = path[path.count - 1], elapsed = time - last.t
        var expectedX = last.x, expectedY = last.y
        var reach = firstJumpReach * max(1, (elapsed * 240).rounded())
        if path.count >= 2 {
            let previous = path[path.count - 2], gap = last.t - previous.t
            expectedX += (last.x - previous.x) / gap * elapsed
            expectedY += (last.y - previous.y) / gap * elapsed
            reach = pathReach
        }

        var nearest: Int?
        for (index, spot) in spots.enumerated() where unclaimed[index] {
            let distance = hypot(spot.x - expectedX, spot.y - expectedY)
            if distance <= reach {
                reach = distance
                nearest = index
            }
        }
        return nearest
    }

    static func travel(_ path: [TrackPoint], _ direction: Double) -> Double {
        direction * (path[path.count - 1].x - path[0].x)
    }
}

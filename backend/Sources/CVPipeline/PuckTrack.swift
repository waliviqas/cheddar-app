import Foundation

/*
This class's only job is: turn a found shot into the puck's exact position in each frame.

ShotFinder says when the shot happened, and the dark spots say where the puck was.
*/
enum PuckTrack {
    private static let lineReach = 7.0, curveReach = 5.0
    private static let minSightings = 6, maxFrameGap = 3, maxRounds = 60
    private static let speeds = 1000.0...14000, maxRise = 0.6
    private static let framesBack = 30, framesAhead = 40
    private static let secondsBefore = 0.12, secondsAfterStart = 0.5, secondsAfterEnd = 0.1

    static func exact(_ flight: Flight, frames: [SpotFrame], towardNet direction: Double) -> [TrackPoint]? {
        guard let first = flight.points.first, let last = flight.points.last else { return nil }
        let end = max(first.t + secondsAfterStart, last.t + secondsAfterEnd)
        let nearby = frames.filter { $0.time >= first.t - secondsBefore && $0.time <= end }

        guard var points = straightestLine(nearby, towardNet: direction) else { return nil }
        for _ in 0..<maxRounds {
            guard points.count >= minSightings else { return nil }
            let next = smoothRun(around: points, nearby)
            if next.map(\.t) == points.map(\.t), next.map(\.x) == points.map(\.x) { return next }
            points = next
        }
        return points.count >= minSightings ? points : nil
    }

    // Tries pairs of spots a few frames apart and keeps the fast line that passes closest to the most spots.
    static func straightestLine(_ frames: [SpotFrame], towardNet direction: Double) -> [TrackPoint]? {
        var best: [TrackPoint] = [], bestScore = 0.0
        for (index, frame) in frames.enumerated() {
            for start in frame.spots {
                for gap in [3, 6, 10] where index + gap < frames.count {
                    let later = frames[index + gap], elapsed = later.time - frame.time
                    for end in later.spots {
                        let speedX = (end.x - start.x) / elapsed, speedY = (end.y - start.y) / elapsed
                        guard direction * speedX > 0, speeds.contains(hypot(speedX, speedY)),
                              abs(speedY) < maxRise * abs(speedX) else { continue }
                        let line = spotsOnLine(from: start, frameIndex: index, speedX, speedY, frames)
                        if line.score > bestScore {
                            bestScore = line.score
                            best = line.points
                        }
                    }
                }
            }
        }
        return best.count >= minSightings ? longestRun(best, frames) : nil
    }

    // Fits a curve through the points, then keeps the spots on it, looking a few frames past each end.
    static func smoothRun(around points: [TrackPoint], _ frames: [SpotFrame]) -> [TrackPoint] {
        let middle = points[points.count / 2].t
        let times = points.map { $0.t - middle }
        let curveX = Solver.polyfit(times, points.map(\.x), degree: 2)
        let curveY = Solver.polyfit(times, points.map(\.y), degree: 2)
        guard let firstFrame = frames.firstIndex(where: { $0.time >= points[0].t }),
              let lastFrame = frames.lastIndex(where: { $0.time <= points[points.count - 1].t }) else { return [] }

        var near: [TrackPoint] = []
        for frame in frames[max(0, firstFrame - maxFrameGap)...min(frames.count - 1, lastFrame + maxFrameGap)] {
            let x = Solver.polyval(curveX, frame.time - middle), y = Solver.polyval(curveY, frame.time - middle)
            guard let nearest = nearestSpot(in: frame, toX: x, y: y), nearest.distance < curveReach else { continue }
            near.append(TrackPoint(t: frame.time, x: nearest.spot.x, y: nearest.spot.y))
        }
        return longestRun(near, frames)
    }

    // The longest stretch with no more than a few frames between neighboring sightings.
    static func longestRun(_ points: [TrackPoint], _ frames: [SpotFrame]) -> [TrackPoint] {
        let frameNumber = Dictionary(frames.enumerated().map { ($0.element.time, $0.offset) }, uniquingKeysWith: { first, _ in first })
        var runs: [[TrackPoint]] = []
        for point in points {
            if let last = runs.last?.last, frameNumber[point.t]! - frameNumber[last.t]! <= maxFrameGap {
                runs[runs.count - 1].append(point)
            } else {
                runs.append([point])
            }
        }
        return runs.max { $0.count < $1.count } ?? []
    }

    // A spot right on the line scores 1, and one at the edge of its reach scores half that.
    private static func spotsOnLine(from start: Spot, frameIndex index: Int, _ speedX: Double, _ speedY: Double,
                                    _ frames: [SpotFrame]) -> (points: [TrackPoint], score: Double) {
        var points: [TrackPoint] = [], score = 0.0
        for frame in frames[max(0, index - framesBack)..<min(frames.count, index + framesAhead)] {
            let elapsed = frame.time - frames[index].time
            guard let nearest = nearestSpot(in: frame, toX: start.x + speedX * elapsed, y: start.y + speedY * elapsed),
                  nearest.distance < lineReach else { continue }
            points.append(TrackPoint(t: frame.time, x: nearest.spot.x, y: nearest.spot.y))
            score += 1 - nearest.distance / lineReach * 0.5
        }
        return (points, score)
    }

    private static func nearestSpot(in frame: SpotFrame, toX x: Double, y: Double) -> (spot: Spot, distance: Double)? {
        var nearest: (spot: Spot, distance: Double)?
        for spot in frame.spots {
            let distance = hypot(spot.x - x, spot.y - y)
            if distance < (nearest?.distance ?? .infinity) { nearest = (spot, distance) }
        }
        return nearest
    }
}

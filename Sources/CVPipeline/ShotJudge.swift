import CoreGraphics

/*
This class's only job is: flights in, the one that is actually a shot out.
*/
public struct ShotJudge {
    public init() {}

    // Picks the farthest-flying straight flight — a shot flies with intent.
    // Wobbles that end near where they began and short crawls are noise, not shots.
    public func shot(among flights: [[CGPoint]]) -> [CGPoint]? {
        let candidates = flights.filter {
            totalDistance(of: $0) >= 100 && straightness(of: $0) >= 0.8
        }
        return candidates.max { totalDistance(of: $0) < totalDistance(of: $1) }
    }

    // How direct a flight was: 1.0 means it never wavered from a straight line.
    private func straightness(of flight: [CGPoint]) -> Double {
        guard let first = flight.first, let last = flight.last else { return 0 }
        let travelled = totalDistance(of: flight)
        guard travelled > 0 else { return 0 }
        let dx = last.x - first.x
        let dy = last.y - first.y
        return (dx * dx + dy * dy).squareRoot() / travelled
    }

    // Adds up how far a flight traveled between each pair of points.
    private func totalDistance(of flight: [CGPoint]) -> Double {
        var total = 0.0
        for i in 1..<max(flight.count, 1) {
            let dx = flight[i].x - flight[i - 1].x
            let dy = flight[i].y - flight[i - 1].y
            total += (dx * dx + dy * dy).squareRoot()
        }
        return total
    }
}

import CoreGraphics

/*
This class's only job is: flights in, the one that is actually a shot out.
*/
public struct ShotJudge {
    public init() {}

    // Picks the flight that covers the most ground, the way a real shot does.
    // Flights that never cover real distance are not shots at all.
    public func shot(among flights: [[CGPoint]]) -> [CGPoint]? {
        let best = flights.max { totalDistance(of: $0) < totalDistance(of: $1) }
        guard let best, totalDistance(of: best) >= 100 else { return nil }
        return best
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

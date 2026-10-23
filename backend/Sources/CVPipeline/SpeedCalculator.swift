import CoreGraphics

/*
This class's only job is: puck path in, shot speed in mph out.
*/
public struct SpeedCalculator {
    public init() {}

    // Turns a puck path into a speed in mph.
    public func mph(path: [CGPoint?], fps: Double, pixelsPerFoot: Double) -> Double? {
        let points = path.compactMap { $0 }
        guard points.count >= 2, fps > 0, pixelsPerFoot > 0 else { return nil }
        guard let gaps = frameGaps(in: path) else { return nil }
        let feet = totalPixelDistance(of: points) / pixelsPerFoot
        let seconds = Double(gaps) / fps
        return mphFrom(feet: feet, seconds: seconds)
    }

    // Turns a puck path into a speed in mph, using each frame's real time in seconds.
    public func mph(path: [CGPoint?], times: [Double], pixelsPerFoot: Double) -> Double? {
        let points = path.compactMap { $0 }
        guard let first = path.firstIndex(where: { $0 != nil }),
              let last = path.lastIndex(where: { $0 != nil }) else { return nil }
        let feet = totalPixelDistance(of: points) / pixelsPerFoot
        let seconds = times[last] - times[first]
        return mphFrom(feet: feet, seconds: seconds)
    }

    // Counts the frame gaps between the first and last time the puck was seen.
    private func frameGaps(in path: [CGPoint?]) -> Int? {
        guard let first = path.firstIndex(where: { $0 != nil }),
              let last = path.lastIndex(where: { $0 != nil }),
              last > first else { return nil }
        return last - first
    }

    // Adds up the distance the puck traveled between each pair of frames.
    private func totalPixelDistance(of points: [CGPoint]) -> Double {
        var total = 0.0
        for i in 1..<points.count {
            let dx = points[i].x - points[i - 1].x
            let dy = points[i].y - points[i - 1].y
            total += (dx * dx + dy * dy).squareRoot()
        }
        return total
    }

    // Converts feet traveled over seconds into miles per hour.
    private func mphFrom(feet: Double, seconds: Double) -> Double {
        return (feet / seconds) * 3600 / 5280
    }
}

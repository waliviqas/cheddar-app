import CoreGraphics

/*
This class's only job is: frames in, shot speed in mph out. It runs the pipeline: eyes, judge, math.
*/
public struct ShotAnalyzer {
    // What the puck looks like, from the setup tap. The eyes need it to spot the puck.
    public let look: PuckLook

    public init(look: PuckLook) {
        self.look = look
    }

    // Gets every flight from the eyes, asks the judge which one is the shot,
    // and hands it to the speed math. Footage too short for flights falls back to plain tracking.
    public func analyze(frames: [CGImage], fps: Double, pixelsPerFoot: Double) -> Double? {
        if let flight = ShotJudge().shot(among: PuckTracker(look: look).flights(in: frames)) {
            return SpeedCalculator().mph(path: flight.map { Optional($0) }, fps: fps, pixelsPerFoot: pixelsPerFoot)
        }
        let path = PuckTracker(look: look).track(frames: frames)
        return SpeedCalculator().mph(path: path, fps: fps, pixelsPerFoot: pixelsPerFoot)
    }

    // Same pipeline, but uses each frame's real time in seconds instead of assuming 1/fps between frames.
    // The judge's flight is laid back onto its frames, so each point is matched with its own time.
    public func analyze(frames: [CGImage], times: [Double], pixelsPerFoot: Double) -> Double? {
        let flights = PuckTracker(look: look).numberedFlights(in: frames)
        if let shot = ShotJudge().shot(among: flights.map { $0.map { $0.point } }),
           let flight = flights.first(where: { $0.map { $0.point } == shot }) {
            var path = [CGPoint?](repeating: nil, count: frames.count)
            for p in flight {
                path[p.frame] = p.point
            }
            return SpeedCalculator().mph(path: path, times: times, pixelsPerFoot: pixelsPerFoot)
        }
        let path = PuckTracker(look: look).track(frames: frames)
        return SpeedCalculator().mph(path: path, times: times, pixelsPerFoot: pixelsPerFoot)
    }
}

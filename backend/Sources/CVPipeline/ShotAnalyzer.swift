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
}

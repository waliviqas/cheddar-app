import CoreGraphics

/*
This class's only job is: frames in, shot speed in mph out. It connects PuckTracker to SpeedCalculator.
*/
public struct ShotAnalyzer {
    public init() {}

    // Tracks the puck through the frames and hands the path to the speed math.
    public func analyze(frames: [CGImage], fps: Double, pixelsPerFoot: Double) -> Double? {
        let path = PuckTracker().track(frames: frames)
        return SpeedCalculator().mph(path: path, fps: fps, pixelsPerFoot: pixelsPerFoot)
    }
}

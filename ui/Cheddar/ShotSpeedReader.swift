import Foundation

/*
This class's only job is: recorded video file in, shot speed in mph out.
The old ShotAnalyzer it used no longer fits the backend; it gets rewired to ClackShotReader after the demo.
*/
struct ShotSpeedReader {
    func mph(from url: URL) async throws -> Double? {
        nil
    }
}

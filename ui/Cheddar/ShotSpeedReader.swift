import AVFoundation
import CVPipeline

/*
This class's only job is: recorded video file in, shot speed in mph out.
It is the UI's one doorway into the CVPipeline backend.
*/
struct ShotSpeedReader {
    // Until the calibration screen exists, we assume this many pixels equal one foot on screen.
    static let placeholderPixelsPerFoot = 100.0

    // Unpacks the video into frames, reads its true frame rate, and asks the backend for the speed.
    func mph(from url: URL) async throws -> Double? {
        let frames = try await VideoFrameExtractor().frames(from: url)
        let fps = try await frameRate(of: url)
        return ShotAnalyzer().analyze(frames: frames, fps: fps, pixelsPerFoot: Self.placeholderPixelsPerFoot)
    }

    // Reads how many frames per second the camera actually captured.
    private func frameRate(of url: URL) async throws -> Double {
        guard let track = try await AVURLAsset(url: url).loadTracks(withMediaType: .video).first else {
            return 240
        }
        return Double(try await track.load(.nominalFrameRate))
    }
}

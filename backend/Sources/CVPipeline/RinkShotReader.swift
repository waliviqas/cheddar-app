import CoreGraphics
import Foundation

/*
This struct's only job is: Video, setup tap, and shot time in, shot speed in mph out.
*/
public struct RinkShotReader {
    public init() {}

    // Calibrates on the tapped puck, cuts out the shot, finds the puck in each frame with the trained model,
    // and reads the speed off the straight line those catches make.
    // The tap is in pixels measured from the top-left, like a tap on the screen.
    public func mph(video: URL, tappedAt tap: CGPoint, tapSeconds: Double, shotStartSeconds: Double) async throws -> Double? {
        let extractor = VideoFrameExtractor()
        guard let tapFrame = try await extractor.frames(from: video, between: tapSeconds, and: tapSeconds + 0.05).first?.image
        else { return nil }
        let spot = CGPoint(x: tap.x, y: Double(tapFrame.height) - tap.y)
        guard let pixelsPerInch = PuckRuler().pixelsPerInch(in: tapFrame, tappedAt: spot) else { return nil }

        let shot = try await extractor.frames(from: video, between: shotStartSeconds - 0.05, and: shotStartSeconds + 0.35)
        let detector = PuckDetector()
        let catches = shot.map { frame in
            (seconds: frame.seconds, points: detector.pucks(in: frame.image).map { CGPoint(x: $0.midX, y: $0.midY) })
        }
        guard let pixelsPerSecond = FlightLine().pixelsPerSecond(frames: catches) else { return nil }
        return pixelsPerSecond / pixelsPerInch / 12 * 3600 / 5280
    }
}

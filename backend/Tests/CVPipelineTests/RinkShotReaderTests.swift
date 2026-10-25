import Testing
import Foundation
import CoreGraphics
@testable import CVPipeline

@Suite("RinkShotReader — held-out clips vs radar")
struct RinkShotReaderTests {

    /*
    - The four shots from the two clips held out of training, run end to end like the app will:
      tap the resting puck to calibrate, cut out the shot, track it with real frame times, read the speed
    - Each shot's tap, timing, and radar speed come from Wali's answer key
    - This test will expect each speed within 5 mph of the radar
    */
    @Test("held-out shots read within 5 mph of the radar", arguments: [
        ("1x/58mph-54mph.MOV", 306.0, 736.0, 6.3, 9.2, 58.0),
        ("1x/58mph-54mph.MOV", 262.0, 769.0, 16.4, 20.0, 54.0),
        ("0.5x/45mph-43mph.MOV", 266.0, 791.0, 5.4, 7.4, 45.0),
        ("0.5x/45mph-43mph.MOV", 203.0, 819.0, 9.5, 16.8, 43.0),
    ])
    func heldOutShotMatchesRadar(clip: String, x: Double, y: Double, tapSeconds: Double, shotStart: Double, radar: Double) async throws {
        let videoURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("videos/rink-clips/\(clip)")
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            return
        }

        let mph = try #require(await RinkShotReader().mph(
            video: videoURL, tappedAt: CGPoint(x: x, y: y), tapSeconds: tapSeconds, shotStartSeconds: shotStart))

        #expect(abs(mph - radar) <= 5, "read \(mph) mph, radar said \(radar)")
    }
}

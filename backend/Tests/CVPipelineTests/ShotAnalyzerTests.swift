import Testing
import Foundation
import CoreGraphics
@testable import CVPipeline

@Suite("ShotAnalyzer")
struct ShotAnalyzerTests {

    /*
    - Three frames drawn 55px apart, 240fps, 100px = 1 foot
    - Frame 1 spends itself proving motion, so the speed comes from the last two
    - This test will expect 90 mph out of the whole pipeline at once
    */
    @Test("three frames through the full pipeline gives 90 mph")
    func fullPipelineSpeed() throws {
        let frames = [
            makeFrame(puckAt: CGPoint(x: 100, y: 100)),
            makeFrame(puckAt: CGPoint(x: 155, y: 100)),
            makeFrame(puckAt: CGPoint(x: 210, y: 100)),
        ]

        let mph = try #require(ShotAnalyzer(look: drawnPuckLook).analyze(frames: frames, fps: 240, pixelsPerFoot: 100))

        #expect(abs(mph - 90.0) < 0.0001)
    }

    /*
    - Real 240fps footage of a ball drop with a 30cm scale marked in frame
    - Gravity is the ground truth: physics says the tracked fall averages ~6.4 mph
    - This test will expect the whole chain (chopper, eyes, judge, math) to land within 0.5 mph
    */
    @Test("free-fall clip reads gravity's speed")
    func freefallGroundTruth() async throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let videoURL = repoRoot.appendingPathComponent("videos/freefall-240fps-gravity.mp4")
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            return
        }

        let allFrames = try await VideoFrameExtractor().frames(from: videoURL)
        let dropWindow = Array(allFrames[120...280])

        let ball = PuckLook(color: CGColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 1), width: 13)
        let mph = try #require(ShotAnalyzer(look: ball).analyze(frames: dropWindow, fps: 240, pixelsPerFoot: 90))

        #expect(abs(mph - 6.4) < 0.5)
    }

    /*
    - Short shot: three frames drawn 55px apart, 100px = 1 foot, too short for Apple's flight detector
    - The real times are 0, 2/240, and 4/240 seconds, so every gap is twice as long, like skipped frames
    - Frame 1 spends itself proving motion, so the speed comes from 55px over 2/240 seconds
    - This test will expect 45 mph, not the 90 mph that assuming 1/240 per frame gives
    */
    @Test("short shot uses the real frame times")
    func shortShotUsesRealTimes() throws {
        let frames = [
            makeFrame(puckAt: CGPoint(x: 100, y: 100)),
            makeFrame(puckAt: CGPoint(x: 155, y: 100)),
            makeFrame(puckAt: CGPoint(x: 210, y: 100)),
        ]

        let mph = try #require(ShotAnalyzer(look: drawnPuckLook).analyze(frames: frames, times: [0, 2.0 / 240, 4.0 / 240], pixelsPerFoot: 100))

        #expect(abs(mph - 45.0) < 0.0001)
    }

    /*
    - Long shot: twenty frames drawn 25px apart, long enough for Apple's flight detector to follow
    - Measured once with normal 1/240-second gaps, then again with every gap twice as long
    - Apple's detector smooths the path a little, so instead of an exact number,
      this test will expect the doubled-gap speed to be half the normal-gap speed, within 1%
    */
    @Test("long shot followed by Apple's flight detector uses the real frame times")
    func longShotUsesRealTimes() throws {
        let frames = (0..<20).map { i in
            makeFrame(puckAt: CGPoint(x: 60 + 25 * Double(i), y: 240))
        }
        let normal = (0..<20).map { Double($0) / 240 }
        let doubled = (0..<20).map { Double($0) * 2 / 240 }
        let analyzer = ShotAnalyzer(look: drawnPuckLook)

        let normalMph = try #require(analyzer.analyze(frames: frames, times: normal, pixelsPerFoot: 100))
        let doubledMph = try #require(analyzer.analyze(frames: frames, times: doubled, pixelsPerFoot: 100))

        #expect(abs(doubledMph / normalMph - 0.5) < 0.005)
    }
}

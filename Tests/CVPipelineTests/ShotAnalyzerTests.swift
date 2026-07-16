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

        let mph = try #require(ShotAnalyzer().analyze(frames: frames, fps: 240, pixelsPerFoot: 100))

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
            return // clip not on this machine; nothing to grade
        }

        let allFrames = try await VideoFrameExtractor().frames(from: videoURL)
        let dropWindow = Array(allFrames[120...280])

        let mph = try #require(ShotAnalyzer().analyze(frames: dropWindow, fps: 240, pixelsPerFoot: 90))

        #expect(abs(mph - 6.4) < 0.5)
    }
}

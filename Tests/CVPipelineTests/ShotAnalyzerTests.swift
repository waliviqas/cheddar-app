import Testing
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
}

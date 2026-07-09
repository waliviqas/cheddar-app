import Testing
import CoreGraphics
@testable import CVPipeline

@Suite("SpeedCalculator")
struct SpeedCalculatorTests {

    /*
    - Puck moves 55px between 2 frames, camera is 240fps, 100px = 1 foot
    - That works out to 132 ft/s, so this test will expect 90 mph
    */
    @Test("two frames with known distance gives 90 mph")
    func twoFrameSpeed() throws {
        let path: [CGPoint?] = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 155, y: 100),
        ]

        let mph = try #require(SpeedCalculator().mph(path: path, fps: 240, pixelsPerFoot: 100))

        #expect(abs(mph - 90.0) < 0.0001)
    }
}

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

    /*
    - Same shot, but the puck was not visible in the first frame
    - The blank frame should not count as travel time, so this test still expects 90 mph
    */
    @Test("blank frame before the puck appears does not slow the reading")
    func ignoresBlankLeadingFrame() throws {
        let path: [CGPoint?] = [
            nil,
            CGPoint(x: 100, y: 100),
            CGPoint(x: 155, y: 100),
        ]

        let mph = try #require(SpeedCalculator().mph(path: path, fps: 240, pixelsPerFoot: 100))

        #expect(abs(mph - 90.0) < 0.0001)
    }

    /*
    - Same shot, but the puck was not visible in the last frame
    - The trailing blank frame should not count as travel time, so this test still expects 90 mph
    */
    @Test("blank frame after the puck disappears does not slow the reading")
    func ignoresBlankTrailingFrame() throws {
        let path: [CGPoint?] = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 155, y: 100),
            nil,
        ]

        let mph = try #require(SpeedCalculator().mph(path: path, fps: 240, pixelsPerFoot: 100))

        #expect(abs(mph - 90.0) < 0.0001)
    }

    /*
    - Puck was missed mid-flight: position is ignored, but the time is not
    - Puck traveled 110px over 2 frame gaps, so this test still expects 90 mph
    */
    @Test("missed frame mid-flight keeps its time but not its position")
    func countsTimeForMissedMiddleFrame() throws {
        let path: [CGPoint?] = [
            CGPoint(x: 100, y: 100),
            nil,
            CGPoint(x: 210, y: 100),
        ]

        let mph = try #require(SpeedCalculator().mph(path: path, fps: 240, pixelsPerFoot: 100))

        #expect(abs(mph - 90.0) < 0.0001)
    }

    /*
    - Puck moves diagonally: 33px across and 44px up, which is 55px of real travel
    - Same distance and time as the first test, so this test still expects 90 mph
    */
    @Test("diagonal movement measures the slanted distance, not just sideways")
    func measuresDiagonalDistance() throws {
        let path: [CGPoint?] = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 133, y: 144),
        ]

        let mph = try #require(SpeedCalculator().mph(path: path, fps: 240, pixelsPerFoot: 100))

        #expect(abs(mph - 90.0) < 0.0001)
    }

    /*
    - Paths where speed cannot be measured: no frames, puck never seen, or only seen once
    - This test will expect nil for all three instead of a made-up number
    */
    @Test("unmeasurable paths come back as nil")
    func returnsNilForUnmeasurablePaths() {
        let calc = SpeedCalculator()

        #expect(calc.mph(path: [], fps: 240, pixelsPerFoot: 100) == nil)
        #expect(calc.mph(path: [nil, nil, nil], fps: 240, pixelsPerFoot: 100) == nil)
        #expect(calc.mph(path: [CGPoint(x: 100, y: 100)], fps: 240, pixelsPerFoot: 100) == nil)
    }

    /*
    - Puck is seen in both frames but never moves
    - This test will expect exactly 0 mph, not nil, since a still puck is still a measurement
    */
    @Test("still puck measures 0 mph")
    func stillPuckIsZeroMph() throws {
        let path: [CGPoint?] = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 100, y: 100),
        ]

        let mph = try #require(SpeedCalculator().mph(path: path, fps: 240, pixelsPerFoot: 100))

        #expect(mph == 0.0)
    }
}

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

    /*
    - Puck moves 100px (1 foot) between 2 frames, and each frame carries its real time: 0 and 1/240 seconds
    - Nothing was skipped, so this is 240 ft/s, and this test will expect about 163.6 mph, the same as the fps version
    */
    @Test("real frame times with no skips give the same speed as fps")
    func realTimesNoSkips() throws {
        let path: [CGPoint?] = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 100),
        ]

        let mph = try #require(SpeedCalculator().mph(path: path, times: [0, 1.0 / 240], pixelsPerFoot: 100))

        #expect(abs(mph - 163.64) < 0.01)
    }

    /*
    - Puck moves 100px (1 foot), then another 100px, but the phone skipped 2 frames in the second stretch
    - The real times are 0, 1/240, and 4/240 seconds, so that's 2 feet in 4/240 seconds, or 120 ft/s
    - This test will expect about 81.8 mph, not the 163.6 mph that assuming 1/240 per frame would give
    */
    @Test("skipped frames use the real, longer time between frames")
    func realTimesWithSkips() throws {
        let path: [CGPoint?] = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 100),
            CGPoint(x: 300, y: 100),
        ]

        let mph = try #require(SpeedCalculator().mph(path: path, times: [0, 1.0 / 240, 4.0 / 240], pixelsPerFoot: 100))

        #expect(abs(mph - 81.82) < 0.01)
    }

    /*
    - Puck is seen in frames 1 and 3, but hidden in frame 2 (behind the stick, or too blurry)
    - Real times are 0, 1/240, and 2/240 seconds, and the puck moved 200px (2 feet) from frame 1 to frame 3
    - The hidden frame's time still counts, so this test will expect 2 feet in 2/240 seconds: about 163.6 mph
    */
    @Test("a hidden puck in a middle frame still counts that frame's time")
    func realTimesWithHiddenPuck() throws {
        let path: [CGPoint?] = [
            CGPoint(x: 100, y: 100),
            nil,
            CGPoint(x: 300, y: 100),
        ]

        let mph = try #require(SpeedCalculator().mph(path: path, times: [0, 1.0 / 240, 2.0 / 240], pixelsPerFoot: 100))

        #expect(abs(mph - 163.64) < 0.01)
    }
}

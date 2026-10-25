import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import CVPipeline

// Loads one still frame from Wali's held-out rink clips, which the model never trained on.
func loadRinkFrame(named name: String) throws -> CGImage {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "Resources/rink-frames"))
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
}

// Whether any box is centered within 15px of a spot given in pixels from the top-left, like Wali's clicks.
// Boxes measure y from the bottom, so the spot is flipped before comparing.
func hasPuck(near spot: (x: Double, y: Double), in boxes: [CGRect], frameHeight: Int) -> Bool {
    let y = Double(frameHeight) - spot.y
    return boxes.contains { abs($0.midX - spot.x) <= 15 && abs($0.midY - y) <= 15 }
}


@Suite("PuckDetector — real held-out frames")
struct PuckDetectorTests {

    /*
    - The four frames where a puck sits still before a shot, from the two clips held out of training
    - The spots are where Wali clicked the resting puck
    - This test will expect a puck found within 15px of each click
    */
    @Test("finds every resting puck", arguments: [
        ("1x-58mph-54mph-s1-rest-006.300", 306.0, 736.0),
        ("1x-58mph-54mph-s2-rest-016.400", 262.0, 769.0),
        ("0.5x-45mph-43mph-s1-rest-005.400", 266.0, 791.0),
        ("0.5x-45mph-43mph-s2-rest-009.500", 203.0, 819.0),
    ])
    func findsRestingPucks(frameName: String, x: Double, y: Double) throws {
        let frame = try loadRinkFrame(named: frameName)

        let boxes = PuckDetector().pucks(in: frame)

        #expect(hasPuck(near: (x, y), in: boxes, frameHeight: frame.height))
    }

    /*
    - Two frames mid-shot, with the puck flying; its spot was checked by eye
    - This test will expect a puck found within 15px of the flying puck
    */
    @Test("finds a flying puck", arguments: [
        ("0.5x-45mph-43mph-s1-fly-007.490", 743.0, 738.0),
        ("1x-58mph-54mph-s2-fly-020.060", 786.0, 737.0),
    ])
    func findsFlyingPucks(frameName: String, x: Double, y: Double) throws {
        let frame = try loadRinkFrame(named: frameName)

        let boxes = PuckDetector().pucks(in: frame)

        #expect(hasPuck(near: (x, y), in: boxes, frameHeight: frame.height))
    }

    /*
    - A 320px patch of bare floor with sun, shadow, and red lines, but no puck
    - This test will expect nothing found
    */
    @Test("finds nothing on bare floor")
    func bareFloorFindsNothing() throws {
        let frame = try loadRinkFrame(named: "1x-58mph-54mph-s1-rest-006.300")
        let floor = try #require(frame.cropping(to: CGRect(x: 1000, y: 740, width: 320, height: 320)))

        let boxes = PuckDetector().pucks(in: floor)

        #expect(boxes.isEmpty)
    }

    /*
    - The resting puck tapped at setup, measured by eye at 18px wide (1x clip) and 28px wide (0.5x clip)
    - A puck is 3 inches, so that's about 6.0 and 9.3 pixels per inch
    - This test will expect PuckRuler, using the model, to land within 10% of each
    */
    @Test("calibration measures the real resting puck", arguments: [
        ("1x-58mph-54mph-s1-rest-006.300", 306.0, 736.0, 6.0),
        ("0.5x-45mph-43mph-s2-rest-009.500", 203.0, 819.0, 9.3),
    ])
    func calibratesOnRealPuck(frameName: String, x: Double, y: Double, expected: Double) throws {
        let frame = try loadRinkFrame(named: frameName)
        let tap = CGPoint(x: x, y: Double(frame.height) - y)

        let scale = try #require(PuckRuler().pixelsPerInch(in: frame, tappedAt: tap))

        #expect(abs(scale - expected) <= expected * 0.1)
    }
}

import CoreGraphics
import Testing
import simd
@testable import CVPipeline

@Suite("FoundCorners")
struct FoundCornersTests {
    // A net seen from the tripod, tapped top-left, top-right, bottom-right, bottom-left, with posts 600 px tall.
    let taps = [Vec2(400, 300), Vec2(1400, 300), Vec2(1400, 900), Vec2(400, 900)]

    @Test("a tap a little off a corner moves onto the corner the model found")
    func sloppyTapMoves() {
        let moved = FoundCorners.nudge(taps, toward: [(label: "topLeft", spot: Vec2(430, 320))])
        #expect(moved == [Vec2(430, 320), taps[1], taps[2], taps[3]])
    }

    @Test("a tap stays put when the model found nothing near it")
    func farFindIgnored() {
        let moved = FoundCorners.nudge(taps, toward: [(label: "topLeft", spot: Vec2(800, 300))])
        #expect(moved == taps)
    }

    @Test("a top-left tap never takes the model's top-right corner")
    func labelsDontSwap() {
        let moved = FoundCorners.nudge(taps, toward: [(label: "topRight", spot: Vec2(410, 305))])
        #expect(moved == taps)
    }

    @Test("the model's box lands on the right video pixel, measured from the top")
    func boxToVideoPixel() {
        let spot = FoundCorners.spot(of: CGRect(x: 0.2, y: 0.7, width: 0.1, height: 0.2), in: Vec2(1920, 1080))
        #expect(simd_distance(spot, Vec2(480, 216)) < 1e-9)
    }
}

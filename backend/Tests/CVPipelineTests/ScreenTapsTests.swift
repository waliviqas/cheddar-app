import Testing
import simd
@testable import CVPipeline

@Suite("ScreenTaps")
struct ScreenTapsTests {
    @Test("the middle of the screen is the middle of the video")
    func middle() {
        #expect(simd_distance(ScreenTaps.pixel(Vec2(463, 214), screen: iPhone14Plus), Vec2(960, 540)) <= 1e-9)
    }

    @Test("the top-left of the screen is 96 down in the video, past the strip the screen hides")
    func topLeft() {
        #expect(simd_distance(ScreenTaps.pixel(Vec2(0, 0), screen: iPhone14Plus), Vec2(0, 96.29)) <= 0.01)
    }

    @Test("the bottom-right of the screen is 984 down in the video")
    func bottomRight() {
        #expect(simd_distance(ScreenTaps.pixel(Vec2(926, 428), screen: iPhone14Plus), Vec2(1920, 983.71)) <= 0.01)
    }

    @Test("your Nov 16 top-left corner, tapped where it shows, lands on the real corner")
    func realCorner() {
        #expect(simd_distance(ScreenTaps.pixel(nov16Taps[0], screen: iPhone14Plus), nov16Corners[0]) <= 0.02)
    }

    @Test("an iPhone 15 Pro screen hides 97 at the top and keeps the middle")
    func otherPhone() {
        let iPhone15Pro = Vec2(852, 393)
        #expect(simd_distance(ScreenTaps.pixel(Vec2(0, 0), screen: iPhone15Pro), Vec2(0, 97.18)) <= 0.01)
        #expect(simd_distance(ScreenTaps.pixel(Vec2(426, 196.5), screen: iPhone15Pro), Vec2(960, 540)) <= 1e-9)
    }

    @Test("corners tapped top-left first come back in the same order")
    func inOrder() throws {
        expectCorners(try #require(ScreenTaps.corners(nov16Taps, screen: iPhone14Plus)), nov16Corners)
    }

    @Test("corners tapped in a random order come back top-left, top-right, bottom-right, bottom-left")
    func randomOrder() throws {
        let taps = [nov16Taps[2], nov16Taps[0], nov16Taps[3], nov16Taps[1]]
        expectCorners(try #require(ScreenTaps.corners(taps, screen: iPhone14Plus)), nov16Corners)
    }

    @Test("a net filmed from the other side comes back in order")
    func otherSide() throws {
        let taps = [Vec2(164.27, 213.13), Vec2(54.6, 400.16), Vec2(51.7, 224.9), Vec2(166.0, 342.77)]
        let truth = [Vec2(107.2, 562.6), Vec2(340.6, 538.2), Vec2(344.2, 807.0), Vec2(113.2, 926.0)]
        expectCorners(try #require(ScreenTaps.corners(taps, screen: iPhone14Plus)), truth)
    }

    @Test("a net tilted 5 degrees by a crooked tripod comes back in order")
    func crookedTripod() throws {
        let taps = [Vec2(756.07, 337.64), Vec2(880.21, 230.17), Vec2(862.05, 404.52), Vec2(769.1, 208.64)]
        let truth = [Vec2(1594.67, 528.89), Vec2(1825.06, 573.54), Vec2(1787.41, 935.03), Vec2(1567.66, 796.35)]
        expectCorners(try #require(ScreenTaps.corners(taps, screen: iPhone14Plus)), truth)
    }

    @Test("a corner found in the video shows on your 14 Plus screen exactly where it sits")
    func videoToScreen() {
        for corner in nov16Corners {
            let onScreen = ScreenTaps.screenPoint(of: corner, screen: iPhone14Plus)
            #expect(simd_distance(ScreenTaps.pixel(onScreen, screen: iPhone14Plus), corner) < 1e-9)
        }
        #expect(simd_distance(ScreenTaps.screenPoint(of: Vec2(960, 540), screen: iPhone14Plus), Vec2(463, 214)) < 1e-9)
    }

    @Test("3 taps give no corners")
    func threeTaps() {
        #expect(ScreenTaps.corners(Array(nov16Taps.prefix(3)), screen: iPhone14Plus) == nil)
    }
}

private let iPhone14Plus = Vec2(926, 428)
private let nov16Taps = [Vec2(761.73, 213.13), Vec2(874.3, 224.9), Vec2(871.4, 400.16), Vec2(760.0, 342.77)]
private let nov16Corners = [Vec2(1579.4, 538.2), Vec2(1812.8, 562.6), Vec2(1806.8, 926.0), Vec2(1575.8, 807.0)]

private func expectCorners(_ found: [Vec2], _ truth: [Vec2]) {
    #expect(found.count == truth.count)
    for (spot, right) in zip(found, truth) {
        #expect(simd_distance(spot, right) <= 0.02)
    }
}

import Testing
import simd
@testable import CVPipeline

@Suite("CameraPose")
struct CameraPoseTests {
    @Test("no turn changes nothing")
    func noTurn() {
        #expect(isClose(CameraPose.turn(Vec3(0, 0, 0)) * Vec3(3, 4, 12), to: Vec3(3, 4, 12)))
    }

    @Test("a quarter turn around up turns along the goal line into toward the shooter")
    func quarterTurn() {
        #expect(isClose(CameraPose.turn(Vec3(0, 0, .pi / 2)) * Vec3(1, 0, 0), to: Vec3(0, 1, 0)))
    }

    @Test("a turn keeps a 13-inch line 13 inches long")
    func turnKeepsLength() {
        #expect(abs(simd_length(CameraPose.turn(Vec3(0.3, -0.2, 0.5)) * Vec3(3, 4, 12)) - 13) <= 1e-9)
    }

    @Test("a spot straight ahead lands in the middle of the picture")
    func straightAhead() {
        #expect(isClose(lookingAhead().pixel(of: Vec3(0, 0, 100)), to: Vec2(960, 540)))
    }

    @Test("a spot to the right lands to the right")
    func spotToTheRight() {
        #expect(isClose(lookingAhead().pixel(of: Vec3(10, 0, 100)), to: Vec2(1107.02, 540)))
    }

    @Test("a lower spot lands lower")
    func lowerSpot() {
        #expect(isClose(lookingAhead().pixel(of: Vec3(0, 10, 100)), to: Vec2(960, 687.02)))
    }

    @Test("a spot twice as far away lands half as far from the middle")
    func twiceAsFar() {
        #expect(isClose(lookingAhead().pixel(of: Vec3(10, 0, 200)), to: Vec2(1033.51, 540)))
    }

    @Test("a different lens changes where a spot lands")
    func differentLens() {
        let pose = lookingAhead(lens: Lens(zoom: 2000, centerX: 1000, centerY: 600))

        #expect(isClose(pose.pixel(of: Vec3(10, 0, 100)), to: Vec2(1200, 600)))
    }

    @Test("moving the phone changes where a spot lands")
    func phoneMoved() {
        let pose = CameraPose(position: Vec3(5, 0, 0), toCamera: matrix_identity_double3x3, lens: iPhone)

        #expect(isClose(pose.pixel(of: Vec3(15, 0, 100)), to: Vec2(1107.02, 540)))
    }

    @Test("turning the phone toward a spot puts it in the middle")
    func phoneTurned() {
        let pose = CameraPose(position: Vec3(0, 0, 0), toCamera: CameraPose.turn(Vec3(0, -.pi / 2, 0)), lens: iPhone)

        #expect(isClose(pose.pixel(of: Vec3(100, 0, 0)), to: Vec2(960, 540)))
    }

    @Test("the middle pixel looks straight out of the lens")
    func middlePixel() {
        #expect(isClose(lookingAhead().ray(Vec2(960, 540)), to: Vec3(0, 0, 1)))
    }

    @Test("a pixel one zoom-length right of the middle looks 45 degrees right")
    func fortyFiveDegrees() {
        let half = 0.5.squareRoot()

        #expect(isClose(lookingAhead().ray(Vec2(960 + 1470.2, 540)), to: Vec3(half, 0, half)))
    }

    @Test("a direction is always 1 inch long")
    func directionLength() {
        #expect(abs(simd_length(nov16().ray(Vec2(100, 900))) - 1) <= 1e-12)
    }

    @Test("the line through a spot's pixel points right at the spot")
    func lineHitsSpot() {
        let pose = nov16(), spot = Vec3(100, 60, 3)

        #expect(isClose(pose.ray(pose.pixel(of: spot)), to: simd_normalize(spot - pose.position)))
    }

    @Test("a spot on the floor is found from its pixel")
    func floorSpot() {
        #expect(isClose(found(Vec3(100, 60, 0), readAt: 0), to: Vec3(100, 60, 0)))
    }

    @Test("a puck's middle 0.75 in up is found from its pixel")
    func puckHeight() {
        #expect(isClose(found(Vec3(100, 60, 0.75), readAt: 0.75), to: Vec3(100, 60, 0.75)))
    }

    @Test("a spot 40 in up is found from its pixel")
    func spotInTheAir() {
        #expect(isClose(found(Vec3(30, 10, 40), readAt: 40), to: Vec3(30, 10, 40)))
    }

    @Test("a spot 3 in up read at floor height lands farther from the phone")
    func wrongHeight() {
        #expect(isClose(found(Vec3(100, 60, 3), readAt: 0), to: Vec3(91.64, 57.18, 0), within: 0.01))
    }

    @Test("perfect corners from the Nov 16 spot give an exact first guess")
    func firstGuessNov16() {
        #expect(isClose(CameraPose.firstGuess(corners(of: nov16()), iPhone)?.position, to: nov16Spot, within: 1e-6))
    }

    @Test("perfect corners from the other side give an exact first guess")
    func firstGuessOtherSide() {
        let otherSide = phone(at: Vec3(-190, 115, 61.5))

        #expect(isClose(CameraPose.firstGuess(corners(of: otherSide), iPhone)?.position, to: otherSide.position, within: 1e-6))
    }

    @Test("corners 1 pixel off give a first guess within 2 in")
    func firstGuessNudged() {
        #expect(isClose(CameraPose.firstGuess(nudged(corners(of: nov16()), by: 1), iPhone)?.position, to: nov16Spot, within: 2))
    }

    @Test("4 corners in a line give no first guess")
    func firstGuessInALine() {
        #expect(CameraPose.firstGuess(inALine, iPhone) == nil)
    }

    @Test("4 corners on one spot give no first guess")
    func firstGuessOneSpot() {
        #expect(CameraPose.firstGuess(oneSpot, iPhone) == nil)
    }

    @Test("the Nov 16 phone spot is found")
    func findsNov16Spot() {
        #expect(isFound(nov16()))
    }

    @Test("a phone 20 ft straight in front of the net is found")
    func findsFrontSpot() {
        #expect(isFound(phone(at: Vec3(36, 240, 48))))
    }

    @Test("the tester spot, 25 ft to the side on a 5 ft tripod, is found")
    func findsTesterSpot() {
        #expect(isFound(phone(at: Vec3(335, 110.5, 60))))
    }

    @Test("a tripod 2 ft off the ground is found")
    func findsLowTripod() {
        #expect(isFound(phone(at: Vec3(-100, 200, 24))))
    }

    @Test("a phone 8 ft from the net is found")
    func findsCloseSpot() {
        #expect(isFound(phone(at: Vec3(36, 96, 40))))
    }

    @Test("a phone 40 ft from the net is found")
    func findsFarSpot() {
        #expect(isFound(phone(at: Vec3(36, 480, 48))))
    }

    @Test("a phone on the other side of the net is found")
    func findsOtherSide() {
        #expect(isFound(phone(at: Vec3(-190, 115, 61.5))))
    }

    @Test("a phone nearly in line with the goal line is found")
    func findsSharpAngle() {
        #expect(isFound(phone(at: Vec3(336, 24, 60))))
    }

    @Test("a phone level with the middle of the net is found")
    func findsLevelPhone() {
        #expect(isFound(phone(at: Vec3(263, 115, 24))))
    }

    @Test("a phone 4 in off the ground is found")
    func findsPhoneOnTheGround() {
        #expect(isFound(phone(at: Vec3(263, 115, 4))))
    }

    @Test("a tripod tilted 5 degrees is found")
    func findsTiltedTripod() {
        #expect(isFound(phone(at: nov16Spot, tilt: 5)))
    }

    @Test("a net near the side of the picture is found")
    func findsOffCenterNet() {
        #expect(isFound(phone(at: Vec3(36, 240, 48), aim: Vec3(-30, 0, 40))))
    }

    @Test("a phone with a different lens is found")
    func findsOtherLens() {
        #expect(isFound(phone(at: nov16Spot, lens: Lens(zoom: 2000, centerX: 1000, centerY: 560))))
    }

    @Test("corners 1 pixel off put the phone within 2 in")
    func onePixelOff() {
        #expect(isFound(nov16(), from: nudged(corners(of: nov16()), by: 1), within: 2))
    }

    @Test("corners 3 pixels off put the phone within 6 in")
    func threePixelsOff() {
        #expect(isFound(nov16(), from: nudged(corners(of: nov16()), by: 3), within: 6))
    }

    @Test("all 4 corners shifted 5 pixels the same way barely move the phone")
    func sameShift() {
        #expect(isFound(nov16(), from: corners(of: nov16()).map { $0 + Vec2(5, 0) }, within: 0.05))
    }

    @Test("the corner miss is near 0 for perfect corners and 0.5 pixels for corners 3 pixels off")
    func cornerMiss() throws {
        let perfect = try #require(CameraPose(corners: corners(of: nov16()), lens: iPhone))
        let offBy3 = try #require(CameraPose(corners: nudged(corners(of: nov16()), by: 3), lens: iPhone))

        #expect(perfect.cornerMissPx < 0.01)
        #expect(abs(offBy3.cornerMissPx - 0.5) <= 0.01)
    }

    @Test("taps shaped like a net 4.5 ft wide give no answer")
    func tooNarrow() {
        #expect(CameraPose(corners: corners(of: nov16(), width: 54), lens: iPhone) == nil)
    }

    @Test("the 9 Nov 16 clips match the tape-measured distance")
    func matchesTape() throws {
        let distances = try nov16Taps.map { simd_distance(try #require(CameraPose(corners: $0, lens: iPhone)).position, shootingSpot) }

        #expect(abs(distances.reduce(0, +) / Double(distances.count) - 247.8) <= 1)
    }

    @Test("the 9 Nov 16 clips give phone heights within 1 in of each other")
    func steadyHeight() throws {
        let heights = try nov16Taps.map { try #require(CameraPose(corners: $0, lens: iPhone)).position.z }

        #expect(heights.max()! - heights.min()! <= 1)
    }

    @Test("all 9 Nov 16 clips are accepted")
    func realClipsAccepted() {
        #expect(nov16Taps.allSatisfy { CameraPose(corners: $0, lens: iPhone) != nil })
    }

    @Test("3 corners give no answer")
    func threeCorners() {
        #expect(CameraPose(corners: Array(corners(of: nov16()).prefix(3)), lens: iPhone) == nil)
    }

    @Test("no corners give no answer")
    func noCorners() {
        #expect(CameraPose(corners: [], lens: iPhone) == nil)
    }

    @Test("4 corners on one spot give no answer")
    func cornersOnOneSpot() {
        #expect(CameraPose(corners: oneSpot, lens: iPhone) == nil)
    }

    @Test("4 corners in a line give no answer")
    func cornersInALine() {
        #expect(CameraPose(corners: inALine, lens: iPhone) == nil)
    }

    @Test("2 corners on one spot give no answer")
    func doubleTap() {
        var taps = corners(of: nov16())
        taps[1] = taps[0]

        #expect(CameraPose(corners: taps, lens: iPhone) == nil)
    }

    @Test("an unreadable corner gives no answer")
    func unreadableCorner() {
        var taps = corners(of: nov16())
        taps[2].x = .nan

        #expect(CameraPose(corners: taps, lens: iPhone) == nil)
    }

    @Test("all 23 wrong tap orders give no answer")
    func wrongOrders() {
        let taps = corners(of: nov16())
        let wrong = orders([0, 1, 2, 3]).filter { $0 != [0, 1, 2, 3] }

        #expect(wrong.count == 23)
        #expect(wrong.filter { CameraPose(corners: $0.map { taps[$0] }, lens: iPhone) != nil }.isEmpty)
    }

    @Test("a lens with zoom 0 gives no answer")
    func zeroZoom() {
        #expect(CameraPose(corners: corners(of: nov16()), lens: Lens(zoom: 0, centerX: 960, centerY: 540)) == nil)
    }

//    @Test("a straight net needs no correction")
//    func straightNet() throws {
//        let pose = try #require(CameraPose(corners: corners(of: nov16()), lens: iPhone))
//
//        #expect(isClose(pose.onFloor(lean: 0).position, to: pose.position))
//    }
//
//    @Test("a net leaning back 1 degree is corrected")
//    func leaningBack() {
//        #expect(isCorrected(lean: 1))
//    }
//
//    @Test("a net leaning forward 1 degree is corrected")
//    func leaningForward() {
//        #expect(isCorrected(lean: -1))
//    }
//
//    @Test("a bent net leaning back 1.5 degrees is corrected")
//    func bentNet() {
//        #expect(isCorrected(lean: 1.5))
//    }
//
//    @Test("the correction keeps the net on the same pixels")
//    func netStaysLinedUp() throws {
//        let taps = leanedCorners(lean: 1)
//        let fixed = try #require(CameraPose(corners: taps, lens: iPhone)).onFloor(lean: 1)
//
//        #expect(zip(leanedNet(lean: 1), taps).allSatisfy { isClose(fixed.pixel(of: $0), to: $1, within: 0.01) })
//    }
//
//    @Test("the correction keeps the lean and the corner miss")
//    func keepsDetails() throws {
//        let pose = try #require(CameraPose(corners: nudged(corners(of: nov16()), by: 3), lens: iPhone))
//        let fixed = pose.onFloor(lean: 1)
//
//        #expect(fixed.netLeanDegrees == 1)
//        #expect(fixed.cornerMissPx == pose.cornerMissPx)
//    }
}

private let iPhone = Lens(zoom: 1470.2, centerX: 960, centerY: 540)
private let nov16Spot = Vec3(263, 115, 61.5)
private let shootingSpot = Vec3(36, 192, 0)
private let inALine = (0..<4).map { Vec2(500 + 100 * Double($0), 500) }
private let oneSpot = Array(repeating: Vec2(500, 500), count: 4)
private let nov16Taps = [
    [Vec2(1579.4, 538.2), Vec2(1812.8, 562.6), Vec2(1806.8, 926.0), Vec2(1575.8, 807.0)],
    [Vec2(1583.5, 530.2), Vec2(1817.1, 554.6), Vec2(1811.0, 918.0), Vec2(1579.7, 799.0)],
    [Vec2(1579.1, 533.1), Vec2(1812.8, 558.9), Vec2(1808.9, 921.0), Vec2(1578.2, 805.0)],
    [Vec2(1582, 539), Vec2(1808, 560), Vec2(1806, 921), Vec2(1577, 802)],
    [Vec2(1581.3, 536.4), Vec2(1813.7, 559.7), Vec2(1808.5, 923.0), Vec2(1578.1, 805.0)],
    [Vec2(1581.4, 536.5), Vec2(1813.5, 560.1), Vec2(1808.5, 926.0), Vec2(1578.4, 805.0)],
    [Vec2(1581.1, 530.3), Vec2(1812.4, 553.1), Vec2(1810.1, 918.0), Vec2(1578.7, 799.0)],
    [Vec2(1581.2, 538.0), Vec2(1812.6, 561.5), Vec2(1807.8, 926.0), Vec2(1577.8, 807.0)],
    [Vec2(1581.2, 538.6), Vec2(1811.9, 561.6), Vec2(1807.1, 926.0), Vec2(1579.4, 807.0)],
]

private func lookingAhead(lens: Lens = iPhone) -> CameraPose {
    CameraPose(position: Vec3(0, 0, 0), toCamera: matrix_identity_double3x3, lens: lens)
}

private func nov16() -> CameraPose {
    phone(at: nov16Spot)
}

private func phone(at spot: Vec3, aim: Vec3 = Vec3(36, 0, 24), tilt: Double = 0, lens: Lens = iPhone) -> CameraPose {
    let forward = simd_normalize(aim - spot)
    let level = simd_normalize(Vec3(-forward.y, forward.x, 0))
    let down = simd_normalize(Vec3(0, 0, -1) + forward.z * forward)
    let angle = tilt * .pi / 180
    let rows = [cos(angle) * level + sin(angle) * down, cos(angle) * down - sin(angle) * level, forward]
    return CameraPose(position: spot, toCamera: simd_double3x3(rows: rows), lens: lens)
}

private func corners(of phone: CameraPose, width: Double = 72) -> [Vec2] {
    [Vec3(0, 0, 48), Vec3(width, 0, 48), Vec3(width, 0, 0), Vec3(0, 0, 0)].map { phone.pixel(of: $0) }
}

private func nudged(_ corners: [Vec2], by pixels: Double) -> [Vec2] {
    zip(corners, [Vec2(pixels, 0), Vec2(0, -pixels), Vec2(-pixels, 0), Vec2(0, pixels)]).map { $0 + $1 }
}

private func found(_ spot: Vec3, readAt height: Double) -> Vec3 {
    let pose = nov16()
    return pose.point(at: pose.pixel(of: spot), height: height)
}

private func isFound(_ phone: CameraPose, from taps: [Vec2]? = nil, within tolerance: Double = 0.01) -> Bool {
    guard let pose = CameraPose(corners: taps ?? corners(of: phone), lens: phone.lens) else { return false }
    return simd_distance(pose.position, phone.position) <= tolerance
}

private func isClose(_ found: Vec3?, to answer: Vec3, within tolerance: Double = 1e-9) -> Bool {
    guard let found else { return false }
    return simd_distance(found, answer) <= tolerance
}

private func isClose(_ found: Vec2, to answer: Vec2, within tolerance: Double = 1e-9) -> Bool {
    simd_distance(found, answer) <= tolerance
}

private func orders(_ items: [Int]) -> [[Int]] {
    guard items.count > 1 else { return [items] }
    return items.indices.flatMap { index in
        var rest = items
        let first = rest.remove(at: index)
        return orders(rest).map { [first] + $0 }
    }
}

//private func leanedNet(lean: Double) -> [Vec3] {
//    let angle = lean * .pi / 180, top = Vec3(0, -48 * sin(angle), 48 * cos(angle))
//    return [top, top + Vec3(72, 0, 0), Vec3(72, 0, 0), Vec3(0, 0, 0)]
//}
//
//private func leanedCorners(lean: Double) -> [Vec2] {
//    leanedNet(lean: lean).map { nov16().pixel(of: $0) }
//}
//
//private func isCorrected(lean: Double) -> Bool {
//    guard let pose = CameraPose(corners: leanedCorners(lean: lean), lens: iPhone) else { return false }
//    return simd_distance(pose.onFloor(lean: lean).position, nov16Spot) <= 0.01
//}

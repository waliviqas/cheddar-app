import Testing
@testable import CVPipeline

@Suite("PuckTrack")
struct PuckTrackTests {
    @Test("a clean flight stays whole")
    func cleanFlightStaysWhole() {
        let kept = PuckTrack.longestRun(sightings(Array(0..<20)), emptyFrames(Array(0..<20)))

        #expect(kept.count == 20)
    }

    @Test("sightings 3 frames apart stay together")
    func threeFramesApart() {
        let slots = Array(stride(from: 0, to: 30, by: 3))

        let kept = PuckTrack.longestRun(sightings(slots), emptyFrames(Array(0..<30)))

        #expect(kept.count == slots.count)
    }

    @Test("a jump of 4 frames splits the sightings and keeps the longer stretch")
    func jumpOfFourFrames() {
        let slots = Array(0..<10) + Array(13..<33)

        let kept = PuckTrack.longestRun(sightings(slots), emptyFrames(Array(0..<33)))

        #expect(kept.count == 20)
        #expect(kept.first?.t == timeOf(13))
    }

    @Test("dropped frames don't split the sightings")
    func droppedFramesStayTogether() {
        let slots = Array(0..<10) + Array(15..<25)

        let kept = PuckTrack.longestRun(sightings(slots), emptyFrames(slots))

        #expect(kept.count == slots.count)
    }

    @Test("no sightings gives nothing")
    func noSightings() {
        #expect(PuckTrack.longestRun([], emptyFrames(Array(0..<10))).isEmpty)
    }

    @Test("a puck flying straight is found in every frame")
    func straightFlight() {
        #expect(PuckTrack.straightestLine(puckFrames(30), towardNet: 1)?.count == 30)
    }

    @Test("a spot 6 pixels off the line is kept")
    func sixPixelsOffLine() {
        let line = PuckTrack.straightestLine(puckFrames(30, offBy: [15: 6]), towardNet: 1)

        #expect(line?.count == 30)
        #expect(line?.contains { $0.y == 706 } == true)
    }

    @Test("a spot 8 pixels off the line is left out")
    func eightPixelsOffLine() {
        let line = PuckTrack.straightestLine(puckFrames(30, offBy: [15: 8]), towardNet: 1)

        #expect(line?.count == 29)
        #expect(line?.contains { $0.t == timeOf(15) } == false)
    }

    @Test("900 pixels per second is too slow for a line")
    func tooSlowForLine() {
        #expect(PuckTrack.straightestLine(puckFrames(60, across: 900.0 / 240), towardNet: 1) == nil)
    }

    @Test("1,100 pixels per second is fast enough for a line")
    func fastEnoughForLine() {
        #expect(PuckTrack.straightestLine(puckFrames(30, across: 1_100.0 / 240), towardNet: 1)?.count == 30)
    }

    @Test("13,900 pixels per second still makes a line")
    func veryHardShot() {
        #expect(PuckTrack.straightestLine(puckFrames(30, across: 13_900.0 / 240), towardNet: 1)?.count == 30)
    }

    @Test("14,100 pixels per second is too fast for a line")
    func tooFastForLine() {
        #expect(PuckTrack.straightestLine(puckFrames(30, across: 14_100.0 / 240), towardNet: 1) == nil)
    }

    @Test("a fast puck moving away from the net makes no line")
    func movingAwayFromNet() {
        #expect(PuckTrack.straightestLine(puckFrames(30), towardNet: -1) == nil)
    }

    @Test("rising 5 pixels for every 10 across still makes a line")
    func risingShot() {
        #expect(PuckTrack.straightestLine(puckFrames(30, across: 20, rising: 10), towardNet: 1)?.count == 30)
    }

    @Test("rising 7 pixels for every 10 across is too steep for a line")
    func tooSteep() {
        #expect(PuckTrack.straightestLine(puckFrames(30, across: 20, rising: 14), towardNet: 1) == nil)
    }

    @Test("5 sightings are too few for a line")
    func tooFewForLine() {
        #expect(PuckTrack.straightestLine(puckFrames(5), towardNet: 1) == nil)
    }

    @Test("6 sightings are enough for a line")
    func enoughForLine() {
        #expect(PuckTrack.straightestLine(puckFrames(6), towardNet: 1)?.count == 6)
    }

    @Test("the puck is followed instead of a shadow that is seen less or wobbles more")
    func puckBeatsShadow() {
        let shadowSeenLess = puckFrames(30).enumerated().map { slot, frame in
            let shadow = Spot(x: frame.spots[0].x, y: 800, size: 100)
            return SpotFrame(time: frame.time, spots: slot < 20 ? [shadow] + frame.spots : frame.spots, changed: 100)
        }
        let shadowWobbles = puckFrames(30).enumerated().map { slot, frame in
            let shadow = Spot(x: frame.spots[0].x, y: slot.isMultiple(of: 2) ? 803 : 797, size: 100)
            return SpotFrame(time: frame.time, spots: [shadow] + frame.spots, changed: 100)
        }

        let overShadowSeenLess = PuckTrack.straightestLine(shadowSeenLess, towardNet: 1)
        let overShadowWobbles = PuckTrack.straightestLine(shadowWobbles, towardNet: 1)

        #expect(overShadowSeenLess?.count == 30)
        #expect(overShadowSeenLess?.allSatisfy { $0.y == 700 } == true)
        #expect(overShadowWobbles?.count == 30)
        #expect(overShadowWobbles?.allSatisfy { $0.y == 700 } == true)
    }

    @Test("a big hole in the line keeps the longer stretch")
    func bigHoleInLine() {
        let frames = puckFrames(38).enumerated().map { slot, frame in
            (10..<18).contains(slot) ? SpotFrame(time: frame.time, spots: [], changed: 100) : frame
        }

        let line = PuckTrack.straightestLine(frames, towardNet: 1)

        #expect(line?.count == 20)
        #expect(line?.first?.t == timeOf(18))
    }

    @Test("no spots gives no line")
    func noSpots() {
        #expect(PuckTrack.straightestLine(emptyFrames(Array(0..<30)), towardNet: 1) == nil)
        #expect(PuckTrack.straightestLine([], towardNet: 1) == nil)
    }

    @Test("the path grows 3 frames past each end")
    func pathGrows() {
        let path = PuckTrack.smoothRun(around: curvePoints(Array(10..<20)), curveFrames(Array(0..<40)))

        #expect(path.count == 16)
        #expect(path.first?.t == timeOf(7))
        #expect(path.last?.t == timeOf(22))
    }

    @Test("a spot 4 pixels off the curve is kept")
    func fourPixelsOffCurve() {
        let clean = Array(0..<20).filter { $0 != 10 }

        let path = PuckTrack.smoothRun(around: curvePoints(clean), curveFrames(Array(0..<20), offBy: [10: 4]))
        let wobbly = path.first { $0.t == timeOf(10) }

        #expect(path.count == 20)
        #expect(wobbly?.y == curveSpot(10, offBy: 4).y)
    }

    @Test("a spot 6 pixels off the curve is left out")
    func sixPixelsOffCurve() {
        let clean = Array(0..<20).filter { $0 != 10 }

        let path = PuckTrack.smoothRun(around: curvePoints(clean), curveFrames(Array(0..<20), offBy: [10: 6]))

        #expect(path.count == 19)
        #expect(path.contains { $0.t == timeOf(10) } == false)
    }

    @Test("the spot closest to the curve counts as the puck")
    func closestSpotWins() {
        let clean = Array(0..<20).filter { $0 != 10 }
        let frames = curveFrames(Array(0..<20)).enumerated().map { slot, frame in
            slot == 10 ? SpotFrame(time: frame.time, spots: [curveSpot(10, offBy: 4), curveSpot(10, offBy: 1)], changed: 100) : frame
        }

        let path = PuckTrack.smoothRun(around: curvePoints(clean), frames)
        let chosen = path.first { $0.t == timeOf(10) }

        #expect(chosen?.y == curveSpot(10, offBy: 1).y)
    }

    @Test("dropped frames don't throw off the curve")
    func droppedFramesOnCurve() {
        let slots = (0..<48).filter { [0, 4, 5, 6, 7].contains($0 % 8) }

        let path = PuckTrack.smoothRun(around: curvePoints(slots), curveFrames(slots))

        #expect(path.count == slots.count)
    }

    @Test("a clean shot keeps every exact position")
    func cleanShot() {
        let frames = puckFrames(60)

        let track = PuckTrack.exact(flight(from: frames), frames: frames, towardNet: 1)

        #expect(track?.map(\.t) == frames.map(\.time))
        #expect(track?.map(\.x) == frames.map { $0.spots[0].x })
        #expect(track?.map(\.y) == frames.map { $0.spots[0].y })
    }

    @Test("a shot that rises and drops is followed from start to finish")
    func curvedShot() {
        let frames = curveFrames(Array(0..<60))

        #expect(PuckTrack.exact(flight(from: frames), frames: frames, towardNet: 1)?.count == 60)
    }

    @Test("the path starts at the first clean frame")
    func startsAtFirstCleanFrame() {
        let frames = puckFrames(60, offBy: [0: 8, 1: 8, 2: 8, 3: 8])

        let track = PuckTrack.exact(flight(from: frames), frames: frames, towardNet: 1)

        #expect(track?.count == 56)
        #expect(track?.first?.t == timeOf(4))
    }

    @Test("the path stops at the net when the puck bounces back")
    func stopsAtTheNet() {
        let frames = (0..<60).map { slot -> SpotFrame in
            let x: Double = slot < 40 ? 300 + 25 * Double(slot) : 1275 - 5 * Double(slot - 39)
            return SpotFrame(time: timeOf(slot), spots: [Spot(x: x, y: 700, size: 100)], changed: 100)
        }

        let track = PuckTrack.exact(flight(from: Array(frames[0..<40])), frames: frames, towardNet: 1)

        #expect(track?.count == 40)
        #expect(track?.last?.t == timeOf(39))
    }

    @Test("a flight cut short at either end still finds the whole shot")
    func flightCutShort() {
        let shortShot = puckFrames(60)
        let longShot = puckFrames(150, across: 10)

        let short = PuckTrack.exact(flight(from: Array(shortShot[20..<30])), frames: shortShot, towardNet: 1)
        let long = PuckTrack.exact(flight(from: Array(longShot[20..<130])), frames: longShot, towardNet: 1)

        #expect(short?.count == 60)
        #expect(short?.first?.t == timeOf(0))
        #expect(long?.count == 150)
    }

    @Test("a second shot a second later stays out of the path")
    func secondShotStaysOut() {
        let frames = (0..<340).map { slot -> SpotFrame in
            let x: Double = slot < 40 ? 300 + 25 * Double(slot) : 300 + 25 * Double(slot - 280)
            let spots = (40..<280).contains(slot) ? [] : [Spot(x: x, y: 700, size: 100)]
            return SpotFrame(time: timeOf(slot), spots: spots, changed: 100)
        }

        let track = PuckTrack.exact(flight(from: Array(frames[0..<40])), frames: frames, towardNet: 1)

        #expect(track?.count == 40)
        #expect(track?.last?.t == timeOf(39))
    }

    @Test("a shot seen in 5 frames gives no answer")
    func tooFewFrames() {
        let frames = puckFrames(5)

        #expect(PuckTrack.exact(flight(from: frames), frames: frames, towardNet: 1) == nil)
    }

    @Test("a flight with no sightings gives no answer")
    func emptyFlight() {
        #expect(PuckTrack.exact(Flight(points: []), frames: puckFrames(60), towardNet: 1) == nil)
    }
}

private func timeOf(_ slot: Int) -> Double {
    5 + Double(slot) / 240
}

private func sightings(_ slots: [Int]) -> [TrackPoint] {
    slots.map { TrackPoint(t: timeOf($0), x: 300 + 25 * Double($0), y: 700) }
}

private func emptyFrames(_ slots: [Int]) -> [SpotFrame] {
    slots.map { SpotFrame(time: timeOf($0), spots: [], changed: 100) }
}

private func puckFrames(_ count: Int, across: Double = 25, rising: Double = 0, offBy: [Int: Double] = [:]) -> [SpotFrame] {
    (0..<count).map { slot in
        let x = 300 + across * Double(slot)
        let y = 700 - rising * Double(slot) + (offBy[slot] ?? 0)
        return SpotFrame(time: timeOf(slot), spots: [Spot(x: x, y: y, size: 100)], changed: 100)
    }
}

private func curveSpot(_ slot: Int, offBy: Double = 0) -> Spot {
    let s = Double(slot)
    return Spot(x: 300 + 25 * s, y: 700 - 6 * s + 0.1 * s * s + offBy, size: 100)
}

private func curveFrames(_ slots: [Int], offBy: [Int: Double] = [:]) -> [SpotFrame] {
    slots.map { SpotFrame(time: timeOf($0), spots: [curveSpot($0, offBy: offBy[$0] ?? 0)], changed: 100) }
}

private func curvePoints(_ slots: [Int]) -> [TrackPoint] {
    slots.map { slot in
        let spot = curveSpot(slot)
        return TrackPoint(t: timeOf(slot), x: spot.x, y: spot.y)
    }
}

private func flight(from frames: [SpotFrame]) -> Flight {
    Flight(points: frames.flatMap { frame in
        frame.spots.map { TrackPoint(t: frame.time, x: $0.x, y: $0.y) }
    })
}

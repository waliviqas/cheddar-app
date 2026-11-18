import Testing
@testable import CVPipeline

@Suite("ShotFinder")
struct ShotFinderTests {
    @Test("a puck seen in every frame makes one path")
    func puckInEveryFrame() {
        let paths = ShotFinder.link(flyingPuck(Array(0..<60)))

        #expect(paths.count == 1)
        #expect(paths.first?.count == 60)
    }

    @Test("dropped or hidden frames don't split the path")
    func droppedFrames() {
        let slots = (0..<120).filter { [0, 4, 5, 6, 7].contains($0 % 8) }
        let hiddenFrames = spotFrames(Array(0..<120)) { slot in
            slots.contains(slot) ? [puck(at: slot)] : []
        }

        let paths = ShotFinder.link(flyingPuck(slots))
        let hiddenPaths = ShotFinder.link(hiddenFrames)

        #expect(paths.count == 1)
        #expect(paths.first?.count == slots.count)
        #expect(hiddenPaths.count == 1)
        #expect(hiddenPaths.first?.count == slots.count)
    }

    @Test("a puck gone for 0.05 seconds starts a new path")
    func goneTooLong() {
        let frames = spotFrames(Array(0..<52)) { slot in
            (20..<32).contains(slot) ? [] : [puck(at: slot)]
        }

        #expect(ShotFinder.link(frames).map(\.count) == [20, 20])
    }

    @Test("a stray spot 31 pixels from the puck's path is left out")
    func straySpot() {
        let frames = spotFrames(Array(0..<20)) { slot in
            slot == 10 ? [Spot(x: 550, y: 731, size: 100)] : [puck(at: slot)]
        }

        let longest = ShotFinder.link(frames).max { $0.count < $1.count }

        #expect(longest?.count == 19)
        #expect(longest?.allSatisfy { $0.y == 700 } == true)
    }

    @Test("a puck and its shadow make two paths")
    func puckAndShadow() {
        let frames = spotFrames(Array(0..<60)) { slot in
            [puck(at: slot), puck(at: slot, y: 800)]
        }

        let paths = ShotFinder.link(frames)

        #expect(paths.count == 2)
        #expect(paths.allSatisfy { $0.count == 60 && Set($0.map(\.y)).count == 1 })
    }

    @Test("a first jump of 90 pixels stays on the same path")
    func firstJumpInReach() {
        let paths = ShotFinder.link(flyingPuck([0, 1], step: 90))

        #expect(paths.count == 1)
        #expect(paths.first?.count == 2)
    }

    @Test("a first jump of 91 pixels starts a new path")
    func firstJumpTooFar() {
        #expect(ShotFinder.link(flyingPuck([0, 1], step: 91)).count == 2)
    }

    @Test("a bumped phone makes no shot")
    func bumpedPhone() {
        let frames = quietFrames() + flyingPuck(Array(0..<60), changed: 20_000)

        #expect(ShotFinder.flights(frames, towardNet: 1).isEmpty)
    }

    @Test("5,000 changed pixels still counts as a steady phone")
    func atTheBumpLimit() {
        let frames = quietFrames() + flyingPuck(Array(0..<60), changed: 5_000)

        #expect(ShotFinder.flights(frames, towardNet: 1).count == 1)
    }

    @Test("5,001 changed pixels counts as a bumped phone")
    func overTheBumpLimit() {
        let frames = quietFrames() + flyingPuck(Array(0..<60), changed: 5_001)

        #expect(ShotFinder.flights(frames, towardNet: 1).isEmpty)
    }

    @Test("a busy background raises the bump limit")
    func busyBackground() {
        let frames = quietFrames(changed: 1_000) + flyingPuck(Array(0..<60), changed: 8_000)

        #expect(ShotFinder.flights(frames, towardNet: 1).count == 1)
    }

    @Test("only the fast part of a path is kept")
    func windupIsCutOff() {
        let whole = path(steps: Array(repeating: 2, count: 100) + Array(repeating: 25, count: 59))

        let part = ShotFinder.fastPart(whole, towardNet: 1)

        #expect(part?.count == 60)
        #expect(part?.first?.t == whole[100].t)
    }

    @Test("a puck moving slowly is not a shot")
    func slowMover() {
        let whole = path(steps: Array(repeating: 2, count: 399))

        #expect(ShotFinder.fastPart(whole, towardNet: 1) == nil)
    }

    @Test("790 pixels per second is too slow to be a shot")
    func justTooSlow() {
        let whole = path(steps: Array(repeating: 790.0 / 240, count: 239))

        #expect(ShotFinder.fastPart(whole, towardNet: 1) == nil)
    }

    @Test("810 pixels per second is fast enough to be a shot")
    func justFastEnough() {
        let whole = path(steps: Array(repeating: 810.0 / 240, count: 239))

        #expect(ShotFinder.fastPart(whole, towardNet: 1)?.count == 240)
    }

    @Test("7 sightings are too few to be a shot")
    func tooFewSightings() {
        let whole = path(steps: Array(repeating: 120, count: 6))

        #expect(ShotFinder.fastPart(whole, towardNet: 1) == nil)
    }

    @Test("8 sightings are enough to be a shot")
    func enoughSightings() {
        let whole = path(steps: Array(repeating: 120, count: 7))

        #expect(ShotFinder.fastPart(whole, towardNet: 1)?.count == 8)
    }

    @Test("599 pixels toward the net is too short to be a shot")
    func tooShort() {
        let whole = path(steps: Array(repeating: 74.875, count: 8))

        #expect(ShotFinder.fastPart(whole, towardNet: 1) == nil)
    }

    @Test("600 pixels toward the net is far enough to be a shot")
    func farEnough() {
        let whole = path(steps: Array(repeating: 75, count: 8))

        #expect(ShotFinder.fastPart(whole, towardNet: 1)?.count == 9)
    }

    @Test("a fast puck moving away from the net is not a shot")
    func movingAwayFromNet() {
        let whole = path(steps: Array(repeating: 25, count: 59))

        #expect(ShotFinder.fastPart(whole, towardNet: -1) == nil)
    }

    @Test("the longest fast run in a path is kept")
    func longestFastRun() {
        let whole = path(steps: Array(repeating: 25, count: 19) + Array(repeating: 2, count: 5) + Array(repeating: 25, count: 39))

        let part = ShotFinder.fastPart(whole, towardNet: 1)

        #expect(part?.count == 40)
        #expect(part?.first?.t == whole[24].t)
    }

    @Test("a shadow that gets lost leaves one shot using the puck")
    func shadowGetsLost() {
        let frames = spotFrames(Array(0..<60)) { slot in
            slot < 30 ? [puck(at: slot, y: 800), puck(at: slot)] : [puck(at: slot)]
        }

        let shots = ShotFinder.flights(frames, towardNet: 1)

        #expect(shots.count == 1)
        #expect(shots.first?.points.count == 60)
        #expect(shots.first?.points.allSatisfy { $0.y == 700 } == true)
    }

    @Test("one shot split into two paths counts once, using the piece that went farthest")
    func splitShot() {
        let frames = spotFrames(Array(0..<92)) { slot in
            slot < 30 || (slot >= 42 && slot.isMultiple(of: 2)) ? [puck(at: slot)] : []
        }

        let shots = ShotFinder.flights(frames, towardNet: 1)

        #expect(shots.count == 1)
        #expect(shots.first?.points.count == 25)
    }

    @Test("two shots a second apart are two shots in time order")
    func twoShots() {
        let frames = spotFrames(Array(0..<500)) { slot in
            var spots = [slot < 60 ? puck(at: slot) : Spot(x: 1775 + Double(slot - 59), y: 700, size: 100)]
            if (300..<360).contains(slot) { spots.append(puck(at: slot - 300, y: 300)) }
            return spots
        }

        let shots = ShotFinder.flights(frames, towardNet: 1)

        #expect(shots.count == 2)
        #expect(shots.first?.points.first?.t == timeOf(0))
        #expect(shots.last?.points.first?.t == timeOf(300))
    }

    @Test("a tie in distance goes to the path with more sightings")
    func tieGoesToMoreSightings() {
        let frames = spotFrames(Array(0..<61)) { slot in
            slot.isMultiple(of: 2) ? [puck(at: slot, y: 300), puck(at: slot)] : [puck(at: slot)]
        }

        let shots = ShotFinder.flights(frames, towardNet: 1)

        #expect(shots.count == 1)
        #expect(shots.first?.points.count == 61)
    }

    @Test("a clip with no puck has no shots")
    func noPuck() {
        #expect(ShotFinder.flights(quietFrames(), towardNet: 1).isEmpty)
        #expect(ShotFinder.flights([], towardNet: 1).isEmpty)
    }
}

private func timeOf(_ slot: Int) -> Double {
    5 + Double(slot) / 240
}

private func puck(at slot: Int, y: Double = 700) -> Spot {
    Spot(x: 300 + 25 * Double(slot), y: y, size: 100)
}

private func spotFrames(_ slots: [Int], changed: Int = 100, spots: (Int) -> [Spot]) -> [SpotFrame] {
    slots.map { SpotFrame(time: timeOf($0), spots: spots($0), changed: changed) }
}

private func flyingPuck(_ slots: [Int], step: Double = 25, changed: Int = 100) -> [SpotFrame] {
    spotFrames(slots, changed: changed) { slot in
        [Spot(x: 300 + step * Double(slot), y: 700, size: 100)]
    }
}

private func quietFrames(changed: Int = 100) -> [SpotFrame] {
    (0..<300).map { SpotFrame(time: Double($0) / 240, spots: [], changed: changed) }
}

private func path(steps: [Double]) -> [TrackPoint] {
    var x = 300.0
    return ([0.0] + steps).enumerated().map { slot, step in
        x += step
        return TrackPoint(t: timeOf(slot), x: x, y: 700)
    }
}

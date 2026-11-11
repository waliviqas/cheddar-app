import Testing
import Foundation
import CoreGraphics
@testable import CVPipeline

/*
PuckLinker gets each frame's real time from the clack on (slow-mo video skips frames now and then), plus where the puck
is at the clack. Each frame it asks the puck model to look only in the 320px square around where the puck should be,
and hands back the shot puck's spot in each frame (nil where it wasn't seen).
Pixels are measured from the top-left, y down.
*/
@Suite("PuckLinker")
struct PuckLinkerTests {

    /*
    - A puck leaves the stick at (200, 900) and moves 30 px right and 6 px up every frame for 20 frames
    - The path should follow it, every frame within 1 px of where the puck really is
    */
    @Test("follows the puck frame by frame")
    func followsThePuck() {
        let truth = flight(from: CGPoint(x: 200, y: 900), step: CGPoint(x: 30, y: -6), frames: 20)

        let path = follow(from: truth[0], through: truth.map { [box(at: $0)] }, times: evenTimes(20))

        #expect(path.count == 20)
        for (spot, real) in zip(path, truth) {
            #expect(distance(spot, real) <= 1)
        }
    }

    /*
    - At the clack there are two puck-looking things: the puck at the stick, and a puck sitting across the rink
    - The path should start at the one at the stick and stay with it
    */
    @Test("starts with the puck at the stick")
    func startsAtTheStick() {
        let truth = flight(from: CGPoint(x: 200, y: 900), step: CGPoint(x: 30, y: -6), frames: 10)
        let elsewhere = CGPoint(x: 1400, y: 300)

        let path = follow(from: CGPoint(x: 205, y: 896), through: truth.map { [box(at: elsewhere), box(at: $0)] }, times: evenTimes(10))

        for (spot, real) in zip(path, truth) {
            #expect(distance(spot, real) <= 1)
        }
    }

    /*
    - The puck flies toward an old puck sitting still in the net, then the model stops seeing the shot
      (it went into the netting)
    - The path should follow the shot, and the still puck should never end up in it: once the shot is gone,
      the path just ends (nil)
    */
    @Test("never latches onto a puck that sits still")
    func ignoresStillPucks() {
        let truth = flight(from: CGPoint(x: 200, y: 900), step: CGPoint(x: 40, y: -8), frames: 15)
        let oldPuck = CGPoint(x: 900, y: 760)
        let frames = (0..<25).map { i in (i < 15 ? [box(at: truth[i])] : []) + [box(at: oldPuck)] }

        let path = follow(from: truth[0], through: frames, times: evenTimes(25))

        for i in 0..<15 {
            #expect(distance(path[i], truth[i]) <= 1, "lost the shot at frame \(i)")
        }
        for spot in path.compactMap({ $0 }) {
            #expect(distance(spot, oldPuck) > 10, "path picked up the still puck")
        }
        for spot in path.dropFirst(15) {
            #expect(spot == nil)
        }
    }

    /*
    - The puck model misses the shot for 2 frames in the middle (too blurry)
    - The path should have nothing for those 2 frames, then pick the puck right back up
    */
    @Test("picks the puck back up after a blurry frame or two")
    func keepsGoingThroughBlur() {
        let truth = flight(from: CGPoint(x: 200, y: 900), step: CGPoint(x: 30, y: -6), frames: 16)
        let frames = truth.enumerated().map { i, p in (i == 8 || i == 9) ? [] : [box(at: p)] }

        let path = follow(from: truth[0], through: frames, times: evenTimes(16))

        #expect(path[8] == nil)
        #expect(path[9] == nil)
        for i in [0, 5, 7, 10, 12, 15] {
            #expect(distance(path[i], truth[i]) <= 1, "frame \(i)")
        }
    }

    /*
    - The video skips 2 frames out of every 10 (like iPhone slow-mo does), so between some frames the puck jumps
      3 times as far as usual
    - The path should still follow it in every frame the video has, within 1 px
    */
    @Test("follows the puck across frames the video skipped")
    func followsThroughSkippedFrames() {
        let kept = (0..<40).filter { $0 % 10 != 8 && $0 % 10 != 9 }
        let truth = kept.map { CGPoint(x: 200 + 30 * CGFloat($0), y: 900 - 6 * CGFloat($0)) }

        let path = follow(from: truth[0], through: truth.map { [box(at: $0)] }, times: kept.map { Double($0) / 240 })

        #expect(path.count == truth.count)
        for (spot, real) in zip(path, truth) {
            #expect(distance(spot, real) <= 1)
        }
    }

    /*
    - Like Wali's real shots: the puck sits at the blade for 6 frames after the clack, then leaves the stick
      and flies 40 px right and 8 px up every frame
    - The path should stay on it while it sits there, catch it the moment it takes off, and follow it the whole way
    */
    @Test("waits at the stick, then catches the puck when it takes off")
    func catchesTheTakeoff() {
        let truth = Array(repeating: CGPoint(x: 200, y: 900), count: 6)
            + (1...20).map { CGPoint(x: 200 + 40 * CGFloat($0), y: 900 - 8 * CGFloat($0)) }

        let path = follow(from: truth[0], through: truth.map { [box(at: $0)] }, times: evenTimes(truth.count))

        for (i, (spot, real)) in zip(path, truth).enumerated() {
            #expect(distance(spot, real) <= 1, "frame \(i)")
        }
    }

    /*
    - Like Wali's real shots: the blade pushes the puck along and it speeds up as it leaves, from about 12 px a frame
      to 30, with the puck model's box wobbling a few pixels each frame
    - The path should stay on it the whole way instead of losing it when it suddenly speeds up
    */
    @Test("keeps following the puck as it speeds up off the blade")
    func followsASpeedingUpPuck() {
        let steps: [CGFloat] = [12, 16, 10, 18, 21, 9, 35, 27, 29, 26, 30, 28, 29, 31, 28, 30, 29, 30]
        var truth = [CGPoint(x: 230, y: 910)]
        for (k, step) in steps.enumerated() {
            let wobble: CGFloat = k % 2 == 0 ? 2 : -2
            truth.append(CGPoint(x: truth.last!.x + step, y: truth.last!.y - step * 0.15 + wobble))
        }

        let path = follow(from: truth[0], through: truth.map { [box(at: $0)] }, times: evenTimes(truth.count))

        for (i, (spot, real)) in zip(path, truth).enumerated() {
            #expect(distance(spot, real) <= 1, "frame \(i)")
        }
    }

    /*
    - A puck flies 40 px right and 8 px up every frame for 20 frames
    - Every frame, PuckLinker's first look should be a square centered within 50 px of where the puck really is,
      and it should never look at more than 3 squares in one frame (looking everywhere is what made it slow)
    */
    @Test("looks where the puck should be next")
    func looksWhereThePuckShouldBe() {
        let truth = flight(from: CGPoint(x: 200, y: 900), step: CGPoint(x: 40, y: -8), frames: 20)
        let detector = FakeDetector(truth.map { [box(at: $0)] })

        _ = PuckLinker().path(from: truth[0], times: evenTimes(20), lookingNear: detector.look)

        for (i, real) in truth.enumerated() {
            let looks = detector.looks.filter { $0.frame == i }
            let first = looks.first?.around
            #expect(first.map { hypot($0.x - real.x, $0.y - real.y) <= 50 } == true, "frame \(i): first looked around \(String(describing: first)), puck at \(real)")
            #expect(looks.count <= 3, "frame \(i): looked at \(looks.count) squares")
        }
    }

    /*
    - Wali's first shot in the 43mph-54mph clip, from the clack to a third of a second later
    - Starts at the puck Wali clicked at the clack (shot-spots.json); boxes come from the real puck model
    - The path should be followed for at least 15 frames and end up at least 600 px closer to the middle of the net
    */
    @Test("follows a real shot toward the net")
    func realShot() async throws {
        let clip = rinkClips.appendingPathComponent("1x-measured/43mph-54mph.MOV")
        let clack = 8.401 - 0.0175   // when the clack was heard, minus the time the sound took to reach the phone
        let frames = try await VideoFrameExtractor().frames(from: clip, between: clack, and: clack + 0.33)
        let start = CGPoint(x: 196, y: 913)
        let netMiddle = CGPoint(x: 1610, y: 830)

        let detector = PuckDetector()

        let path = PuckLinker().path(from: start, times: frames.map { $0.seconds - frames[0].seconds }) { i, spot in
            detector.pucks(in: frames[i].image, near: spot)
        }

        let seen = path.compactMap { $0 }
        #expect(seen.count >= 15, "only followed the puck for \(seen.count) frames")
        let last = try #require(seen.last)
        #expect(distance(start, netMiddle) - distance(last, netMiddle) >= 600, "ended at \(last)")
    }
}

// Follows a made-up shot, handing the boxes over through a fake puck model.
private func follow(from start: CGPoint, through frames: [[CGRect]], times: [Double]) -> [CGPoint?] {
    PuckLinker().path(from: start, times: times, lookingNear: FakeDetector(frames).look)
}

// Stands in for the puck model: holds made-up boxes for each frame and, when asked to look around a spot, answers with
// only the boxes inside the 320px square there. Remembers every square it was asked about.
private final class FakeDetector {
    private let frames: [[CGRect]]
    private(set) var looks: [(frame: Int, around: CGPoint)] = []

    init(_ frames: [[CGRect]]) { self.frames = frames }

    func look(_ frame: Int, _ around: CGPoint) -> [CGRect] {
        looks.append((frame, around))
        let square = CGRect(x: around.x - 160, y: around.y - 160, width: 320, height: 320)
        return frames[frame].filter { square.contains(CGPoint(x: $0.midX, y: $0.midY)) }
    }
}

// Frame times when the video doesn't skip any: 1/240 s apart.
private func evenTimes(_ n: Int) -> [Double] { (0..<n).map { Double($0) / 240 } }

// Where a puck is in each frame when it moves the same amount every frame.
private func flight(from start: CGPoint, step: CGPoint, frames: Int) -> [CGPoint] {
    (0..<frames).map { CGPoint(x: start.x + step.x * CGFloat($0), y: start.y + step.y * CGFloat($0)) }
}

// A puck-sized box (14 px) around a spot, like the puck model gives back.
private func box(at p: CGPoint) -> CGRect { CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14) }

private func distance(_ a: CGPoint?, _ b: CGPoint) -> Double {
    guard let a else { return .infinity }
    return Double(((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot())
}

private let rinkClips = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("videos/rink-clips")

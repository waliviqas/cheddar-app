import Testing
import Foundation
import CoreGraphics
@testable import CVPipeline

/*
PuckLinker gets every puck-looking box the puck model saw in each frame, starting at the clack frame,
plus where the puck is at the clack. It hands back the shot puck's spot in each frame (nil where it wasn't seen).
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

        let path = PuckLinker().path(from: truth[0], through: truth.map { [box(at: $0)] })

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

        let path = PuckLinker().path(from: CGPoint(x: 205, y: 896), through: truth.map { [box(at: elsewhere), box(at: $0)] })

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

        let path = PuckLinker().path(from: truth[0], through: frames)

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

        let path = PuckLinker().path(from: truth[0], through: frames)

        #expect(path[8] == nil)
        #expect(path[9] == nil)
        for i in [0, 5, 7, 10, 12, 15] {
            #expect(distance(path[i], truth[i]) <= 1, "frame \(i)")
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
        let boxes = frames.map { frame in
            // The puck model measures y from the bottom; flip to y down like everything else.
            detector.pucks(in: frame.image).map { CGRect(x: $0.minX, y: CGFloat(frame.image.height) - $0.maxY, width: $0.width, height: $0.height) }
        }
        let path = PuckLinker().path(from: start, through: boxes)

        let seen = path.compactMap { $0 }
        #expect(seen.count >= 15, "only followed the puck for \(seen.count) frames")
        let last = try #require(seen.last)
        #expect(distance(start, netMiddle) - distance(last, netMiddle) >= 600, "ended at \(last)")
    }
}

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

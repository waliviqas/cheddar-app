import Testing
import CoreGraphics
@testable import CVPipeline

// Helper method (test passes in where to put the puck?). Draws a white 640x480 frame with a 20px black puck centered at `center`
// (y measured from the bottom).
func makeFrame(puckAt center: CGPoint, size: CGSize = CGSize(width: 640, height: 480)) -> CGImage {
    let ctx = CGContext(
        data: nil,
        width: Int(size.width), height: Int(size.height),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(origin: .zero, size: size))
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: center.x - 10, y: center.y - 10, width: 20, height: 20))
    return ctx.makeImage()!
}

// Draws a white 640x480 frame with a gray puck at `puckAt` and a darker,
// flashier black decoy at `decoyAt` — a temptation for the tracker.
func makeDecoyFrame(puckAt puck: CGPoint, decoyAt decoy: CGPoint, size: CGSize = CGSize(width: 640, height: 480)) -> CGImage {
    let ctx = CGContext(
        data: nil,
        width: Int(size.width), height: Int(size.height),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(origin: .zero, size: size))
    ctx.setFillColor(CGColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: puck.x - 10, y: puck.y - 10, width: 20, height: 20))
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: decoy.x - 10, y: decoy.y - 10, width: 20, height: 20))
    return ctx.makeImage()!
}

// Draws a plain white 640x480 frame with nothing on it.
func makeBlankFrame(size: CGSize = CGSize(width: 640, height: 480)) -> CGImage {
    let ctx = CGContext(
        data: nil,
        width: Int(size.width), height: Int(size.height),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(origin: .zero, size: size))
    return ctx.makeImage()!
}


@Suite("PuckTracker — single frame")
struct PuckTrackerSingleFrameTests {

    /*
    - Checks whether the appropriate pixels are output 
    - This test will expect an output of (300, 400)
    */
    @Test("finds the puck where we drew it")
    func findsPuck() throws {
        let frame = makeFrame(puckAt: CGPoint(x: 300, y: 400))

        let found = try #require(PuckTracker().detect(in: frame))

        #expect(found == CGPoint(x: 300, y: 400))
    }


    /*
    - Checks whether the appropriate pixels are output
    - This test will expect each of the 5 positions back exactly as the puck moves
    */
    @Test("finds the puck across 5 frames as it moves")
    func findsPuckAcrossFrames() throws {
        let path = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 150, y: 120),
            CGPoint(x: 200, y: 140),
            CGPoint(x: 250, y: 160),
            CGPoint(x: 300, y: 180),
        ]

        for position in path {
            let frame = makeFrame(puckAt: position)
            let found = try #require(PuckTracker().detect(in: frame))
            #expect(found == position)
        }
    }

    /*
    - Checks that a whole batch of frames goes in and a whole batch of positions comes out
    - Frame 1 is nil since one frame cannot prove movement yet
    - This test will expect nil and then the 4 remaining positions, in the same order
    */
    @Test("tracks the puck through a batch of 5 frames")
    func tracksBatchOfFrames() throws {
        let path = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 150, y: 120),
            CGPoint(x: 200, y: 140),
            CGPoint(x: 250, y: 160),
            CGPoint(x: 300, y: 180),
        ]

        let frames = path.map { makeFrame(puckAt: $0) }

        let positions = PuckTracker().track(frames: frames)

        let expected: [CGPoint?] = [nil] + path.dropFirst().map { Optional($0) }
        #expect(positions == expected)
    }

    /*
    - Checks what happens when a frame has no puck in it
    - This test will expect nil back
    */
    @Test("returns nil when there is no puck in the frame")
    func returnsNilForEmptyFrame() {
        let blankFrame = makeBlankFrame()

        let found = PuckTracker().detect(in: blankFrame)

        #expect(found == nil)
    }

    /*
    - Frame 1 has only the puck, so the tracker locks on
    - Then a flashier decoy appears far away while the puck keeps moving
    - This test will expect track to stay with the puck's path, never jumping to the decoy
    */
    @Test("track follows the puck it locked onto, not a flashier decoy")
    func staysWithThePuck() {
        let puckPath = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 110, y: 100),
            CGPoint(x: 120, y: 100),
            CGPoint(x: 130, y: 100),
            CGPoint(x: 140, y: 100),
        ]
        let decoy = CGPoint(x: 500, y: 400)

        var frames = [makeFrame(puckAt: puckPath[0])]
        for position in puckPath.dropFirst() {
            frames.append(makeDecoyFrame(puckAt: position, decoyAt: decoy))
        }

        let positions = PuckTracker().track(frames: frames)

        let expected: [CGPoint?] = [nil] + puckPath.dropFirst().map { Optional($0) }
        #expect(positions == expected)
    }

    /*
    - Frames 1-2 have only the puck, moving 70px per frame, so the tracker learns its speed
    - Then a decoy parks exactly where the puck used to be while the puck keeps flying
    - This test will expect track to lead the moving puck, not grab the decoy behind it
    */
    @Test("track predicts where a fast puck is going instead of clinging to where it was")
    func leadsTheMovingPuck() {
        let puckPath = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 170, y: 100),
            CGPoint(x: 240, y: 100),
            CGPoint(x: 310, y: 100),
            CGPoint(x: 380, y: 100),
        ]
        let decoy = CGPoint(x: 170, y: 100)

        var frames = [
            makeFrame(puckAt: puckPath[0]),
            makeFrame(puckAt: puckPath[1]),
        ]
        for position in puckPath.dropFirst(2) {
            frames.append(makeDecoyFrame(puckAt: position, decoyAt: decoy))
        }

        let positions = PuckTracker().track(frames: frames)

        let expected: [CGPoint?] = [nil] + puckPath.dropFirst().map { Optional($0) }
        #expect(positions == expected)
    }

    /*
    - A glove-like blob wobbles around the same spot in every frame while the puck fires off in a straight line
    - Movement must be seen twice in the same direction before the tracker commits, so frames 1-2 are nil
    - This test will expect the flying puck's positions from frame 3 on, and the wobbler never
    */
    @Test("track locks onto sustained motion, not a wobbling glove")
    func ignoresWobblerLocksOntoFlyer() {
        let puckPath = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 170, y: 100),
            CGPoint(x: 240, y: 100),
            CGPoint(x: 310, y: 100),
            CGPoint(x: 380, y: 100),
        ]
        let glovePath = [
            CGPoint(x: 300, y: 300),
            CGPoint(x: 308, y: 300),
            CGPoint(x: 292, y: 300),
            CGPoint(x: 308, y: 300),
            CGPoint(x: 292, y: 300),
        ]

        let frames = zip(puckPath, glovePath).map { puck, glove in
            makeDecoyFrame(puckAt: puck, decoyAt: glove)
        }

        let positions = PuckTracker().track(frames: frames)

        let expected: [CGPoint?] = [nil, nil] + puckPath.dropFirst(2).map { Optional($0) }
        #expect(positions == expected)
    }

    /*
    - The puck stickhandles around the same spot a few times, then suddenly fires
    - The tracker reports all real movement, so the wobbles are positions, not nils
    - This test will expect the lock to survive the sudden fire without losing the puck
    */
    @Test("track follows the puck through stickhandling and holds on when it fires")
    func followsStickhandlingIntoTheShot() {
        let path = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 108, y: 100),
            CGPoint(x: 92, y: 100),
            CGPoint(x: 108, y: 100),
            CGPoint(x: 178, y: 100),
            CGPoint(x: 248, y: 100),
            CGPoint(x: 318, y: 100),
        ]

        let frames = path.map { makeFrame(puckAt: $0) }

        let positions = PuckTracker().track(frames: frames)

        let expected: [CGPoint?] = [nil] + path.dropFirst().map { Optional($0) }
        #expect(positions == expected)
    }

    /*
    - Two objects fly at once: the puck straight along y=240, a second object on a diagonal
    - Each must come back as its own separate flight, no points mixed between them
    - This test will expect exactly 2 flights, each staying on its own object's line
    */
    @Test("reports two flying objects as two separate flights, never mashed")
    func keepsFlightsSeparate() throws {
        var frames: [CGImage] = []
        for i in 0..<20 {
            let puck = CGPoint(x: 60 + 25 * Double(i), y: 240)
            let other = CGPoint(x: 100 + 12 * Double(i), y: 400 - 8 * Double(i))
            frames.append(makeDecoyFrame(puckAt: puck, decoyAt: other))
        }

        let flights = PuckTracker().flights(in: frames)

        #expect(flights.count == 2)

        func onFlatLine(_ p: CGPoint) -> Bool {
            return abs(p.y - 240) <= 5
        }
        func onDiagonalLine(_ p: CGPoint) -> Bool {
            let expectedY = 400 - (8.0 / 12.0) * (p.x - 100)
            return abs(p.y - expectedY) <= 8
        }

        let flat = flights.first { $0.allSatisfy(onFlatLine) }
        let diagonal = flights.first { $0.allSatisfy(onDiagonalLine) }

        #expect((flat?.count ?? 0) >= 5)
        #expect((diagonal?.count ?? 0) >= 5)
    }
}

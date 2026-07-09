import Testing
import CoreGraphics
@testable import CheddarCore

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
    - This test will expect the 5 positions back as one list, in the same order
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

        #expect(positions == path)
    }
}

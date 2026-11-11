import Testing
import CoreGraphics
@testable import CVPipeline

// Draws a white 640x480 frame with a black puck of the given size centered at `center`
// (y measured from the bottom).
func makeSizedPuckFrame(width: Double, height: Double, at center: CGPoint) -> CGImage {
    let size = CGSize(width: 640, height: 480)
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
    ctx.fillEllipse(in: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height))
    return ctx.makeImage()!
}


@Suite("PuckRuler")
struct PuckRulerTests {

    /*
    - A puck 30 pixels wide, tapped dead center
    - A puck is 3 inches wide, so 30 / 3 = 10 pixels per inch
    - This test will expect about 10
    */
    @Test("a 30-pixel puck measures 10 pixels per inch")
    func measuresPuck() throws {
        let frame = makeSizedPuckFrame(width: 30, height: 30, at: CGPoint(x: 300, y: 240))

        let scale = try #require(PuckRuler().pixelsPerInch(in: frame, tappedAt: CGPoint(x: 300, y: 240)))

        #expect(abs(scale - 10) <= 0.2)
    }

    /*
    - Five frames of the same 30-pixel puck, like a puck seen across a shot, with where the puck is in each
    - This test will expect about 10 pixels per inch from the middle measurement
    */
    @Test("many frames of the same puck measure 10 pixels per inch")
    func measuresAcrossFrames() throws {
        let spot = CGPoint(x: 300, y: 240)
        let frames = (0..<5).map { _ in (image: makeSizedPuckFrame(width: 30, height: 30, at: spot), spot: spot) }

        let scale = try #require(PuckRuler().pixelsPerInch(in: frames))

        #expect(abs(scale - 10) <= 0.2)
    }

    /*
    - Seven frames: most show the puck 30 pixels wide, but one looks flipped (10 wide) and one blurry (45 wide)
    - The middle measurement ignores the odd ones
    - This test will expect about 10 pixels per inch
    */
    @Test("a few odd frames don't change the measurement")
    func oddFramesIgnored() throws {
        let spot = CGPoint(x: 300, y: 240)
        let frames = [30.0, 30, 10, 30, 45, 30, 30].map { width in
            (image: makeSizedPuckFrame(width: width, height: 30, at: spot), spot: spot)
        }

        let scale = try #require(PuckRuler().pixelsPerInch(in: frames))

        #expect(abs(scale - 10) <= 0.2)
    }

    /*
    - Five frames, but one is empty floor where the puck wasn't caught
    - That frame is skipped
    - This test will expect about 10 pixels per inch from the other four
    */
    @Test("a frame with no puck is skipped")
    func emptyFrameSkipped() throws {
        let spot = CGPoint(x: 300, y: 240)
        var frames = (0..<5).map { _ in (image: makeSizedPuckFrame(width: 30, height: 30, at: spot), spot: spot) }
        frames[2].image = makeBlankFrame()

        let scale = try #require(PuckRuler().pixelsPerInch(in: frames))

        #expect(abs(scale - 10) <= 0.2)
    }
}

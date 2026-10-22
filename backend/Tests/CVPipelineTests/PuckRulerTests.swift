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
    - Same 30-pixel puck, but the tap lands 8 right and 5 up from center, still on the puck
    - The row under the tap is shorter than the puck's full width
    - This test will expect about 10, the full width, not the short row
    */
    @Test("a tap off the center still measures 10")
    func offCenterTap() throws {
        let frame = makeSizedPuckFrame(width: 30, height: 30, at: CGPoint(x: 300, y: 240))

        let scale = try #require(PuckRuler().pixelsPerInch(in: frame, tappedAt: CGPoint(x: 308, y: 245)))

        #expect(abs(scale - 10) <= 0.2)
    }

    /*
    - Same 30-pixel puck, but the tap lands 12 left of center, near the left edge
    - This test will expect about 10
    */
    @Test("a tap near the left edge still measures 10")
    func leftEdgeTap() throws {
        let frame = makeSizedPuckFrame(width: 30, height: 30, at: CGPoint(x: 300, y: 240))

        let scale = try #require(PuckRuler().pixelsPerInch(in: frame, tappedAt: CGPoint(x: 288, y: 240)))

        #expect(abs(scale - 10) <= 0.2)
    }

    /*
    - Same 30-pixel puck, but the tap lands 12 below center, near the bottom edge
    - This test will expect about 10
    */
    @Test("a tap near the bottom edge still measures 10")
    func bottomEdgeTap() throws {
        let frame = makeSizedPuckFrame(width: 30, height: 30, at: CGPoint(x: 300, y: 240))

        let scale = try #require(PuckRuler().pixelsPerInch(in: frame, tappedAt: CGPoint(x: 300, y: 228)))

        #expect(abs(scale - 10) <= 0.2)
    }

    /*
    - Same 30-pixel puck, but the tap lands 9 right and 9 up, near the top-right edge
    - This test will expect about 10
    */
    @Test("a tap near the top-right edge still measures 10")
    func topRightEdgeTap() throws {
        let frame = makeSizedPuckFrame(width: 30, height: 30, at: CGPoint(x: 300, y: 240))

        let scale = try #require(PuckRuler().pixelsPerInch(in: frame, tappedAt: CGPoint(x: 309, y: 249)))

        #expect(abs(scale - 10) <= 0.2)
    }
}

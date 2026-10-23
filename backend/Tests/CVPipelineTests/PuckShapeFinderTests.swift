import Testing
import CoreGraphics
@testable import CVPipeline

// Draws a white 640x480 frame with a red line 12px tall running across it at `lineY`,
// and a black 30px puck centered at `center` (y measured from the bottom).
func makeRedLineFrame(puckAt center: CGPoint, lineY: Double) -> CGImage {
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
    ctx.setFillColor(CGColor(red: 0.8, green: 0, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: lineY - 6, width: size.width, height: 12))
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: center.x - 15, y: center.y - 15, width: 30, height: 30))
    return ctx.makeImage()!
}

// Draws a dim gray 640x480 frame, like a poorly lit rink, with a black 30px puck centered at `center`
// (y measured from the bottom).
func makeDimIceFrame(puckAt center: CGPoint) -> CGImage {
    let size = CGSize(width: 640, height: 480)
    let ctx = CGContext(
        data: nil,
        width: Int(size.width), height: Int(size.height),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.setFillColor(CGColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1))
    ctx.fill(CGRect(origin: .zero, size: size))
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: center.x - 15, y: center.y - 15, width: 30, height: 30))
    return ctx.makeImage()!
}


@Suite("PuckShapeFinder")
struct PuckShapeFinderTests {

    /*
    - A 30-pixel puck, tapped dead center
    - This test will expect a box around the whole puck: 30 wide, centered at (300, 240)
    */
    @Test("a tap on the puck finds it")
    func findsPuck() throws {
        let frame = makeSizedPuckFrame(width: 30, height: 30, at: CGPoint(x: 300, y: 240))

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - Same puck, but the tap lands 8 right and 5 up from center, still on the puck
    - This test will expect a box around the whole puck: 30 wide, centered at (300, 240)
    */
    @Test("a tap off the center still finds the whole puck")
    func offCenterTap() throws {
        let frame = makeSizedPuckFrame(width: 30, height: 30, at: CGPoint(x: 300, y: 240))

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 308, y: 245)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - Same puck, but the tap lands 12 left of center, near the left edge
    - This test will expect a box around the whole puck: 30 wide, centered at (300, 240)
    */
    @Test("a tap near the left edge still finds the whole puck")
    func leftEdgeTap() throws {
        let frame = makeSizedPuckFrame(width: 30, height: 30, at: CGPoint(x: 300, y: 240))

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 288, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - Same puck, but the tap lands 12 below center, near the bottom edge
    - This test will expect a box around the whole puck: 30 wide, centered at (300, 240)
    */
    @Test("a tap near the bottom edge still finds the whole puck")
    func bottomEdgeTap() throws {
        let frame = makeSizedPuckFrame(width: 30, height: 30, at: CGPoint(x: 300, y: 240))

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 228)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - Same puck, but the tap lands 9 right and 9 up, near the top-right edge
    - This test will expect a box around the whole puck: 30 wide, centered at (300, 240)
    */
    @Test("a tap near the top-right edge still finds the whole puck")
    func topRightEdgeTap() throws {
        let frame = makeSizedPuckFrame(width: 30, height: 30, at: CGPoint(x: 300, y: 240))

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 309, y: 249)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - Same puck, but the tap lands on bare ice far away from it
    - This test will expect nil
    */
    @Test("a tap on bare ice finds nothing")
    func bareIceTap() {
        let frame = makeSizedPuckFrame(width: 30, height: 30, at: CGPoint(x: 300, y: 240))

        let box = PuckShapeFinder().puck(in: frame, near: CGPoint(x: 500, y: 240))

        #expect(box == nil)
    }

    /*
    - The puck sits right on top of a red line that runs across the whole ice
    - This test will expect only the puck back: 30 wide, centered at (300, 240), not the long line
    */
    @Test("a puck on the red line is found without the line")
    func puckOnRedLine() throws {
        let frame = makeRedLineFrame(puckAt: CGPoint(x: 300, y: 240), lineY: 240)

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - The ice is dim gray instead of white, like a poorly lit rink
    - This test will expect the puck to still be found: 30 wide, centered at (300, 240)
    */
    @Test("a puck on dim ice is still found")
    func puckOnDimIce() throws {
        let frame = makeDimIceFrame(puckAt: CGPoint(x: 300, y: 240))

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - A puck seen from a low angle: 30 wide but only 10 tall
    - This test will expect a box 30 wide and 10 tall, centered at (300, 240)
    */
    @Test("a squashed puck is still found")
    func squashedPuck() throws {
        let frame = makeSizedPuckFrame(width: 30, height: 10, at: CGPoint(x: 300, y: 240))

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.height - 10) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }
}

// Makes a color from red, green, and blue amounts (0-1).
func rgb(_ r: Double, _ g: Double, _ b: Double) -> CGColor {
    return CGColor(red: r, green: g, blue: b, alpha: 1)
}

// Draws a 640x480 frame filled with `floor`, then lets `draw` paint pucks, lines, or shadows on top
// (y measured from the bottom).
func makeFloorFrame(floor: CGColor, draw: (CGContext) -> Void) -> CGImage {
    let size = CGSize(width: 640, height: 480)
    let ctx = CGContext(
        data: nil,
        width: Int(size.width), height: Int(size.height),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.setFillColor(floor)
    ctx.fill(CGRect(origin: .zero, size: size))
    draw(ctx)
    return ctx.makeImage()!
}

// Paints a puck of the given color and size centered at `center`.
func drawPuck(_ ctx: CGContext, color: CGColor, at center: CGPoint, width: Double = 30, height: Double = 30) {
    ctx.setFillColor(color)
    ctx.fillEllipse(in: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height))
}


@Suite("PuckShapeFinder — colored pucks")
struct PuckShapeFinderColorTests {

    /*
    - An orange puck on a gray floor, tapped dead center
    - This test will expect a box around the whole puck: 30 wide, centered at (300, 240)
    */
    @Test("an orange puck on a gray floor is found")
    func orangeOnGray() throws {
        let frame = makeFloorFrame(floor: rgb(0.5, 0.5, 0.5)) { drawPuck($0, color: rgb(1, 0.5, 0), at: CGPoint(x: 300, y: 240)) }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - A yellow puck on a white floor: nearly the same brightness, only the color is different
    - This test will expect a box around the whole puck: 30 wide, centered at (300, 240)
    */
    @Test("a yellow puck on a white floor is found")
    func yellowOnWhite() throws {
        let frame = makeFloorFrame(floor: rgb(1, 1, 1)) { drawPuck($0, color: rgb(1, 0.9, 0.1), at: CGPoint(x: 300, y: 240)) }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - A green puck on a gray floor, tapped dead center
    - This test will expect a box around the whole puck: 30 wide, centered at (300, 240)
    */
    @Test("a green puck on a gray floor is found")
    func greenOnGray() throws {
        let frame = makeFloorFrame(floor: rgb(0.5, 0.5, 0.5)) { drawPuck($0, color: rgb(0.1, 0.7, 0.2), at: CGPoint(x: 300, y: 240)) }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - A blue puck on a light gray floor, tapped dead center
    - This test will expect a box around the whole puck: 30 wide, centered at (300, 240)
    */
    @Test("a blue puck on a light gray floor is found")
    func blueOnLightGray() throws {
        let frame = makeFloorFrame(floor: rgb(0.8, 0.8, 0.8)) { drawPuck($0, color: rgb(0.1, 0.3, 0.9), at: CGPoint(x: 300, y: 240)) }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - A pink puck on a white floor, tapped dead center
    - This test will expect a box around the whole puck: 30 wide, centered at (300, 240)
    */
    @Test("a pink puck on a white floor is found")
    func pinkOnWhite() throws {
        let frame = makeFloorFrame(floor: rgb(1, 1, 1)) { drawPuck($0, color: rgb(1, 0.6, 0.8), at: CGPoint(x: 300, y: 240)) }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - A red puck on a gray floor, tapped dead center
    - This test will expect a box around the whole puck: 30 wide, centered at (300, 240)
    */
    @Test("a red puck on a gray floor is found")
    func redOnGray() throws {
        let frame = makeFloorFrame(floor: rgb(0.5, 0.5, 0.5)) { drawPuck($0, color: rgb(0.85, 0.1, 0.1), at: CGPoint(x: 300, y: 240)) }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - A white puck on a dark floor: the reverse of a black puck on white
    - This test will expect a box around the whole puck: 30 wide, centered at (300, 240)
    */
    @Test("a white puck on a dark floor is found")
    func whiteOnDark() throws {
        let frame = makeFloorFrame(floor: rgb(0.15, 0.15, 0.15)) { drawPuck($0, color: rgb(1, 1, 1), at: CGPoint(x: 300, y: 240)) }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - A purple puck, a color no other test uses, so the code cannot be relying on a list of colors
    - This test will expect a box around the whole puck: 30 wide, centered at (300, 240)
    */
    @Test("a purple puck is found")
    func purpleOnGray() throws {
        let frame = makeFloorFrame(floor: rgb(0.5, 0.5, 0.5)) { drawPuck($0, color: rgb(0.5, 0.1, 0.7), at: CGPoint(x: 300, y: 240)) }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - An orange puck, but the tap lands 10 right and 8 down, near the edge
    - This test will expect a box around the whole puck: 30 wide, centered at (300, 240)
    */
    @Test("an orange puck tapped near its edge is found whole")
    func orangeEdgeTap() throws {
        let frame = makeFloorFrame(floor: rgb(0.5, 0.5, 0.5)) { drawPuck($0, color: rgb(1, 0.5, 0), at: CGPoint(x: 300, y: 240)) }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 310, y: 232)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - An orange puck, but the tap lands on bare floor 40 to its right
    - This test will expect nil
    */
    @Test("a tap on bare floor next to an orange puck finds nothing")
    func bareFloorNextToOrange() {
        let frame = makeFloorFrame(floor: rgb(0.5, 0.5, 0.5)) { drawPuck($0, color: rgb(1, 0.5, 0), at: CGPoint(x: 300, y: 240)) }

        let box = PuckShapeFinder().puck(in: frame, near: CGPoint(x: 340, y: 240))

        #expect(box == nil)
    }

    /*
    - A black puck at x=200 and an orange puck at x=300, and the tap lands on the orange one
    - This test will expect only the orange puck: 30 wide, centered at (300, 240)
    */
    @Test("with a black and an orange puck, the tapped orange one is found")
    func picksTappedPuckOfTwoColors() throws {
        let frame = makeFloorFrame(floor: rgb(0.5, 0.5, 0.5)) {
            drawPuck($0, color: rgb(0, 0, 0), at: CGPoint(x: 200, y: 240))
            drawPuck($0, color: rgb(1, 0.5, 0), at: CGPoint(x: 300, y: 240))
        }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - Two orange pucks at x=200 and x=400, and the tap lands on the left one
    - This test will expect only the left puck: 30 wide, centered at (200, 240)
    */
    @Test("with two orange pucks, only the tapped one is found")
    func picksTappedPuckOfSameColor() throws {
        let frame = makeFloorFrame(floor: rgb(0.5, 0.5, 0.5)) {
            drawPuck($0, color: rgb(1, 0.5, 0), at: CGPoint(x: 200, y: 240))
            drawPuck($0, color: rgb(1, 0.5, 0), at: CGPoint(x: 400, y: 240))
        }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 200, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 200) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - An orange puck on a dim floor, like a poorly lit rink
    - This test will expect a box around the whole puck: 30 wide, centered at (300, 240)
    */
    @Test("an orange puck on a dim floor is found")
    func orangeOnDim() throws {
        let frame = makeFloorFrame(floor: rgb(0.25, 0.25, 0.25)) { drawPuck($0, color: rgb(0.6, 0.3, 0), at: CGPoint(x: 300, y: 240)) }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - An orange puck with a white glare spot on it, and the tap lands on the orange part
    - This test will expect the whole puck, not split by the glare: 30 wide, centered at (300, 240)
    */
    @Test("an orange puck with a glare spot is found whole")
    func orangeWithGlare() throws {
        let frame = makeFloorFrame(floor: rgb(0.5, 0.5, 0.5)) {
            drawPuck($0, color: rgb(1, 0.5, 0), at: CGPoint(x: 300, y: 240))
            drawPuck($0, color: rgb(1, 1, 1), at: CGPoint(x: 296, y: 246), width: 8, height: 6)
        }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 306, y: 234)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - An orange puck whose bottom half is darker, like real light coming from above
    - The tap lands on the bright top half
    - This test will expect the whole puck, both halves: 30 wide, centered at (300, 240)
    */
    @Test("an orange puck with a shaded bottom half is found whole")
    func orangeWithShading() throws {
        let frame = makeFloorFrame(floor: rgb(0.5, 0.5, 0.5)) {
            drawPuck($0, color: rgb(1, 0.5, 0), at: CGPoint(x: 300, y: 240))
            $0.saveGState()
            $0.clip(to: CGRect(x: 0, y: 0, width: 640, height: 240))
            drawPuck($0, color: rgb(0.7, 0.35, 0), at: CGPoint(x: 300, y: 240))
            $0.restoreGState()
        }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 248)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - An orange puck in hard sun, with a gray shadow attached to its lower right
    - This test will expect only the puck, not the shadow: 30 wide, centered at (300, 240)
    */
    @Test("an orange puck with an attached shadow is found without the shadow")
    func orangeWithShadow() throws {
        let frame = makeFloorFrame(floor: rgb(0.85, 0.85, 0.85)) {
            drawPuck($0, color: rgb(0.3, 0.3, 0.3), at: CGPoint(x: 318, y: 230), width: 30, height: 12)
            drawPuck($0, color: rgb(1, 0.5, 0), at: CGPoint(x: 300, y: 240))
        }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - An orange puck sitting on a blue line that runs across the whole floor
    - This test will expect only the puck, not the line: 30 wide, centered at (300, 240)
    */
    @Test("an orange puck on a blue line is found without the line")
    func orangeOnBlueLine() throws {
        let frame = makeFloorFrame(floor: rgb(0.5, 0.5, 0.5)) {
            $0.setFillColor(rgb(0.1, 0.2, 0.8))
            $0.fill(CGRect(x: 0, y: 234, width: 640, height: 12))
            drawPuck($0, color: rgb(1, 0.5, 0), at: CGPoint(x: 300, y: 240))
        }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }

    /*
    - An orange puck seen from a low angle: 30 wide but only 10 tall
    - This test will expect a box 30 wide and 10 tall, centered at (300, 240)
    */
    @Test("a squashed orange puck is found")
    func squashedOrange() throws {
        let frame = makeFloorFrame(floor: rgb(0.5, 0.5, 0.5)) { drawPuck($0, color: rgb(1, 0.5, 0), at: CGPoint(x: 300, y: 240), height: 10) }

        let box = try #require(PuckShapeFinder().puck(in: frame, near: CGPoint(x: 300, y: 240)))

        #expect(abs(box.width - 30) <= 1)
        #expect(abs(box.height - 10) <= 1)
        #expect(abs(box.midX - 300) <= 1)
        #expect(abs(box.midY - 240) <= 1)
    }
}


@Suite("PuckShapeFinder — no tap")
struct PuckShapeFinderNoTapTests {

    /*
    - Two orange pucks at x=200 and x=400, and the finder is told to look for an orange 30px puck
    - This test will expect both pucks back, each 30 wide, at x=200 and x=400
    */
    @Test("finds every puck that matches the look")
    func findsBothMatchingPucks() {
        let frame = makeFloorFrame(floor: rgb(0.5, 0.5, 0.5)) {
            drawPuck($0, color: rgb(1, 0.5, 0), at: CGPoint(x: 200, y: 240))
            drawPuck($0, color: rgb(1, 0.5, 0), at: CGPoint(x: 400, y: 240))
        }

        let boxes = PuckShapeFinder().pucks(in: frame, like: PuckLook(color: rgb(1, 0.5, 0), width: 30))
            .sorted { $0.midX < $1.midX }

        #expect(boxes.count == 2)
        #expect(boxes.allSatisfy { abs($0.width - 30) <= 1 && abs($0.midY - 240) <= 1 })
        #expect(abs((boxes.first?.midX ?? 0) - 200) <= 1)
        #expect(abs((boxes.last?.midX ?? 0) - 400) <= 1)
    }

    /*
    - A black puck at x=200 and an orange puck at x=400, and the finder is told to look for orange
    - This test will expect only the orange puck back, at x=400
    */
    @Test("ignores pucks of a different color")
    func ignoresOtherColors() {
        let frame = makeFloorFrame(floor: rgb(0.5, 0.5, 0.5)) {
            drawPuck($0, color: rgb(0, 0, 0), at: CGPoint(x: 200, y: 240))
            drawPuck($0, color: rgb(1, 0.5, 0), at: CGPoint(x: 400, y: 240))
        }

        let boxes = PuckShapeFinder().pucks(in: frame, like: PuckLook(color: rgb(1, 0.5, 0), width: 30))

        #expect(boxes.count == 1)
        #expect(abs((boxes.first?.width ?? 0) - 30) <= 1)
        #expect(abs((boxes.first?.midX ?? 0) - 400) <= 1)
    }

    /*
    - An orange puck at x=200 and a big orange blob 120x80 at x=450, and the finder is told to look for a 30px orange puck
    - This test will expect only the puck back, at x=200, not the blob
    */
    @Test("ignores same-colored things the wrong size")
    func ignoresWrongSize() {
        let frame = makeFloorFrame(floor: rgb(0.5, 0.5, 0.5)) {
            drawPuck($0, color: rgb(1, 0.5, 0), at: CGPoint(x: 200, y: 240))
            drawPuck($0, color: rgb(1, 0.5, 0), at: CGPoint(x: 450, y: 240), width: 120, height: 80)
        }

        let boxes = PuckShapeFinder().pucks(in: frame, like: PuckLook(color: rgb(1, 0.5, 0), width: 30))

        #expect(boxes.count == 1)
        #expect(abs((boxes.first?.width ?? 0) - 30) <= 1)
        #expect(abs((boxes.first?.midX ?? 0) - 200) <= 1)
    }

    /*
    - Only a black puck in the frame, and the finder is told to look for orange
    - This test will expect nothing back
    */
    @Test("finds nothing when no puck matches the look")
    func findsNothingWithoutMatch() {
        let frame = makeFloorFrame(floor: rgb(0.5, 0.5, 0.5)) {
            drawPuck($0, color: rgb(0, 0, 0), at: CGPoint(x: 300, y: 240))
        }

        let boxes = PuckShapeFinder().pucks(in: frame, like: PuckLook(color: rgb(1, 0.5, 0), width: 30))

        #expect(boxes.isEmpty)
    }
}

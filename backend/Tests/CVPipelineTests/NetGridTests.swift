import Testing
@testable import CVPipeline

@Suite("NetGrid")
struct NetGridTests {
    @Test("a spot well inside each of the 9 squares gets that square's name")
    func eachSquare() {
        #expect(NetGrid.square(across: 10, up: 40) == .topLeft)
        #expect(NetGrid.square(across: 36, up: 40) == .topMiddle)
        #expect(NetGrid.square(across: 62, up: 40) == .topRight)
        #expect(NetGrid.square(across: 10, up: 24) == .middleLeft)
        #expect(NetGrid.square(across: 36, up: 24) == .middle)
        #expect(NetGrid.square(across: 62, up: 24) == .middleRight)
        #expect(NetGrid.square(across: 10, up: 8) == .bottomLeft)
        #expect(NetGrid.square(across: 36, up: 8) == .bottomMiddle)
        #expect(NetGrid.square(across: 62, up: 8) == .bottomRight)
    }

    @Test("a puck just left of the 24 in line is top left")
    func justLeftOfLine() {
        #expect(NetGrid.square(across: 23.5, up: 40) == .topLeft)
    }

    @Test("a puck just right of the 24 in line is top middle")
    func justRightOfLine() {
        #expect(NetGrid.square(across: 24.5, up: 40) == .topMiddle)
    }

    @Test("a middle exactly on an up-and-down line goes toward the center")
    func onUpAndDownLine() {
        #expect(NetGrid.square(across: 24, up: 40) == .topMiddle)
        #expect(NetGrid.square(across: 48, up: 40) == .topMiddle)
    }

    @Test("a middle exactly on a side-to-side line goes toward the center")
    func onSideToSideLine() {
        #expect(NetGrid.square(across: 10, up: 16) == .middleLeft)
        #expect(NetGrid.square(across: 36, up: 32) == .middle)
    }

    @Test("a post-and-in off the left post counts in middle left")
    func leftPostAndIn() {
        #expect(NetGrid.square(across: 1, up: 24) == .middleLeft)
    }

    @Test("a bar-down counts in top middle")
    func barDown() {
        #expect(NetGrid.square(across: 36, up: 47) == .topMiddle)
    }

    @Test("a post-and-in off the right post counts in middle right")
    func rightPostAndIn() {
        #expect(NetGrid.square(across: 71, up: 24) == .middleRight)
    }

    @Test("a puck sliding along the ground counts in bottom middle")
    func slider() {
        #expect(NetGrid.square(across: 36, up: 0.75) == .bottomMiddle)
    }
}

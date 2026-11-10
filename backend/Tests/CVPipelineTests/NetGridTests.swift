import Testing
import Foundation
import CoreGraphics
import simd
@testable import CVPipeline

/*
The opening is 72 in across and 48 in up, measured on the front of the net: across runs from the left post (0)
to the right post (72), up runs from the ice (0) to the crossbar (48). The grid is 3 × 3, so each square is
24 in across and 16 in up. A puck is 3 in across, so it only counts as in when all of it fits inside the opening.
*/
@Suite("NetGrid")
struct NetGridTests {

    /*
    - A pretend phone 233 in in front of the goal line, 30 in left of the left post, 61.5 in off the ice
    - The grid's 4 inside lines (2 up-and-down at 24 and 48 in across, 2 side-to-side at 16 and 32 in up)
      are worked out by math for where they'd land in its picture
    - NetGrid's lines should start and end within half a pixel of those spots
    */
    @Test("puts the grid lines in the right place in the picture")
    func gridLines() throws {
        let phone = PretendPhone(at: SIMD3(-30, 233, 61.5), aimedAt: SIMD3(60, 0, 24))
        let grid = try phone.netGrid()
        let expected = [
            (SIMD3(24.0, 0, 0), SIMD3(24.0, 0, 48)), (SIMD3(48.0, 0, 0), SIMD3(48.0, 0, 48)),
            (SIMD3(0.0, 0, 16), SIMD3(72.0, 0, 16)), (SIMD3(0.0, 0, 32), SIMD3(72.0, 0, 32)),
        ].map { (phone.picture(of: $0.0), phone.picture(of: $0.1)) }

        #expect(grid.lines.count == 4)
        for (line, truth) in zip(grid.lines, expected) {
            #expect(distance(line.start, truth.0) <= 0.5)
            #expect(distance(line.end, truth.1) <= 0.5)
        }
    }

    /*
    - Pucks crossing well inside each part of the opening
    - Each should get the right square: top-left, middle, bottom-right, and so on
    */
    @Test("names the square the puck went through")
    func rightSquare() throws {
        let grid = try PretendPhone(at: SIMD3(-30, 233, 61.5), aimedAt: SIMD3(60, 0, 24)).netGrid()

        #expect(grid.square(across: 10, up: 40) == .topLeft)
        #expect(grid.square(across: 36, up: 40) == .topMiddle)
        #expect(grid.square(across: 62, up: 40) == .topRight)
        #expect(grid.square(across: 10, up: 24) == .middleLeft)
        #expect(grid.square(across: 36, up: 24) == .middle)
        #expect(grid.square(across: 62, up: 24) == .middleRight)
        #expect(grid.square(across: 10, up: 8) == .bottomLeft)
        #expect(grid.square(across: 36, up: 8) == .bottomMiddle)
        #expect(grid.square(across: 62, up: 8) == .bottomRight)
    }

    /*
    - Pucks straddling the line between two squares
    - Each counts for the square its middle is in; a middle exactly on a line goes to the square closer to the
      middle of the net, so there's always one answer
    */
    @Test("picks one square when the puck sits on a grid line")
    func onAGridLine() throws {
        let grid = try PretendPhone(at: SIMD3(-30, 233, 61.5), aimedAt: SIMD3(60, 0, 24)).netGrid()

        #expect(grid.square(across: 23.5, up: 40) == .topLeft)      // straddling, middle just left of the line
        #expect(grid.square(across: 24.5, up: 40) == .topMiddle)    // straddling, middle just right of the line
        #expect(grid.square(across: 24, up: 40) == .topMiddle)      // exactly on the line: toward the middle
        #expect(grid.square(across: 48, up: 40) == .topMiddle)
        #expect(grid.square(across: 36, up: 32) == .middle)
        #expect(grid.square(across: 10, up: 16) == .middleLeft)
    }

    /*
    - Pucks crossing the goal line nowhere near the net: wide to the right, and over the crossbar
    - Each should be called a miss
    */
    @Test("calls it a miss when the puck isn't near the opening")
    func missed() throws {
        let grid = try PretendPhone(at: SIMD3(-30, 233, 61.5), aimedAt: SIMD3(60, 0, 24)).netGrid()

        #expect(grid.square(across: 90, up: 24) == .missed)
        #expect(grid.square(across: 36, up: 60) == .missed)
    }

    /*
    - Pucks whose middle is inside the opening but whose edge still touches the frame:
      1 in from the left post, 1 in under the crossbar, and tucked into a rounded top corner (6 in bend)
      where it would fit if the corner were square
    - None of them fully fit inside, so each should count as hitting the post, not a goal
    */
    @Test("counts a puck touching the frame as hitting the post")
    func hitsThePost() throws {
        let phone = PretendPhone(at: SIMD3(-30, 233, 61.5), aimedAt: SIMD3(60, 0, 24))
        let square = try phone.netGrid()
        let rounded = try phone.netGrid(cornerBend: 6)

        #expect(square.square(across: 1, up: 24) == .post)
        #expect(square.square(across: 36, up: 47) == .post)
        #expect(square.square(across: 2.5, up: 45.5) == .topLeft)    // fits when the corner is square...
        #expect(rounded.square(across: 2.5, up: 45.5) == .post)      // ...but not when it's rounded
    }
}

// A typical iPhone 1x camera (26 mm equivalent) filming 1920 px wide.
private let iPhoneLens = LensInfo(width: 1920, height: 1080, centerX: 960, centerY: 540, zoom: 1920.0 * 26 / 36)

// A perfect pinhole camera at a known spot, aimed at a known point, with no tilt to the side.
private struct PretendPhone {
    let position: SIMD3<Double>
    let forward: SIMD3<Double>
    let right: SIMD3<Double>
    let down: SIMD3<Double>

    init(at position: SIMD3<Double>, aimedAt target: SIMD3<Double>) {
        self.position = position
        forward = simd_normalize(target - position)
        right = simd_normalize(simd_cross(SIMD3(0, 0, 1), forward))
        down = simd_cross(right, forward)
    }

    // p is in net coordinates: x across the goal line, y out toward the shooter, z up.
    func picture(of p: SIMD3<Double>) -> CGPoint {
        let d = p - position
        let (x, y, z) = (simd_dot(d, right), simd_dot(d, down), simd_dot(d, forward))
        return CGPoint(x: iPhoneLens.centerX + iPhoneLens.zoom * x / z, y: iPhoneLens.centerY + iPhoneLens.zoom * y / z)
    }

    // The grid for this phone, with the camera's place worked out from the net's inside corners like the real app.
    func netGrid(cornerBend: Double = 0) throws -> NetGrid {
        let corners = [SIMD3(0.0, 0, 48), SIMD3(72.0, 0, 48), SIMD3(72.0, 0, 0), SIMD3(0.0, 0, 0)].map(picture(of:))
        return NetGrid(pose: try #require(CameraPose(corners: corners, lens: iPhoneLens)), lens: iPhoneLens, cornerBend: cornerBend)
    }
}

private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
    Double(((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot())
}

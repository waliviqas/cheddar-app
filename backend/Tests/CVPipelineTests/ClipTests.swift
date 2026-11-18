import Testing
@testable import CVPipeline

@Suite("Picture")
struct PictureTests {
    let picture = Picture(width: 2, height: 2, rgb: [
        255, 0, 0, 0, 255, 0,
        0, 0, 255, 255, 255, 255,
    ])

    @Test("reads the color at a spot")
    func readsColor() {
        #expect(isColor(picture.color(1, 0), red: 0, green: 255, blue: 0))
    }

    @Test("the top row stays on top")
    func topRowOnTop() {
        #expect(isColor(picture.color(0, 0), red: 255, green: 0, blue: 0))
        #expect(isColor(picture.color(0, 1), red: 0, green: 0, blue: 255))
    }

    @Test("a spot past the right edge has no color")
    func pastRightEdge() {
        #expect(picture.color(2, 0) == nil)
    }

    @Test("a spot above, left of or below the picture has no color")
    func outsideThePicture() {
        #expect(picture.color(0, -1) == nil)
        #expect(picture.color(-1, 1) == nil)
        #expect(picture.color(0, 2) == nil)
    }
}

private func isColor(_ found: (r: Int, g: Int, b: Int)?, red: Int, green: Int, blue: Int) -> Bool {
    guard let found else { return false }
    return found.r == red && found.g == green && found.b == blue
}

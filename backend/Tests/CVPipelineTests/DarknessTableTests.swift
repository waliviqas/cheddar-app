import Testing
@testable import CVPipeline

@Suite("DarknessTable")
struct DarknessTableTests {
    @Test("full range: brightness 0 is fully dark")
    func fullRangeBlack() {
        #expect(DarknessTable.fullRange.darkness(y: 0, cb: 128, cr: 128) == 255)
    }

    @Test("full range: brightness 255 is not dark at all")
    func fullRangeWhite() {
        #expect(DarknessTable.fullRange.darkness(y: 255, cb: 128, cr: 128) == 0)
    }

    @Test("full range: brightness 128 lands in the middle")
    func fullRangeGray() {
        #expect(DarknessTable.fullRange.darkness(y: 128, cb: 128, cr: 128) == 127)
    }

    @Test("video range: brightness 16 is fully dark")
    func videoRangeBlack() {
        #expect(DarknessTable.videoRange.darkness(y: 16, cb: 128, cr: 128) == 255)
    }

    @Test("video range: brightness 235 is not dark at all")
    func videoRangeWhite() {
        #expect(DarknessTable.videoRange.darkness(y: 235, cb: 128, cr: 128) == 0)
    }

    @Test("video range: brightness 126 lands in the middle")
    func videoRangeGray() {
        #expect(DarknessTable.videoRange.darkness(y: 126, cb: 128, cr: 128) == 127)
    }

    @Test("video range: brightness 0, below black, stays fully dark instead of wrapping")
    func videoRangeBelowBlack() {
        #expect(DarknessTable.videoRange.darkness(y: 0, cb: 128, cr: 128) == 255)
    }

    @Test("video range: brightness 255, above white, stays not dark instead of wrapping")
    func videoRangeAboveWhite() {
        #expect(DarknessTable.videoRange.darkness(y: 255, cb: 128, cr: 128) == 0)
    }

    @Test("a blue puck is as dark as today's math says: 235")
    func bluePuck() {
        #expect(DarknessTable.fullRange.darkness(y: 37, cb: 245, cr: 117) == 235)
    }

    @Test("the red net frame is barely dark, as today's math says: 55")
    func redNetFrame() {
        #expect(DarknessTable.fullRange.darkness(y: 66, cb: 109, cr: 213) == 55)
    }

    @Test("every one of the 16.7 million color values comes within 1 of the exact math, in both ranges")
    func everyColor() {
        for fullRange in [true, false] {
            let table = fullRange ? DarknessTable.fullRange : DarknessTable.videoRange
            var worst = 0
            for cb in 0...255 {
                for cr in 0...255 {
                    for y in 0...255 {
                        let got = Int(table.darkness(y: UInt8(y), cb: UInt8(cb), cr: UInt8(cr)))
                        worst = max(worst, abs(got - exactDarkness(y, cb, cr, fullRange: fullRange)))
                    }
                }
            }
            #expect(worst <= 1)
        }
    }
}

// Today's darkness, 255 minus the bigger of red and green, with the camera's color math (BT.709) done with decimals.
private func exactDarkness(_ y: Int, _ cb: Int, _ cr: Int, fullRange: Bool) -> Int {
    let yScale = fullRange ? 1.0 : 255.0 / 219, yOffset = fullRange ? 0.0 : 16, cScale = fullRange ? 1.0 : 255.0 / 224
    let luma = (Double(y) - yOffset) * yScale, blue = (Double(cb) - 128) * cScale, red = (Double(cr) - 128) * cScale
    let redOrGreen = luma + max(1.5748 * red, -0.1873 * blue - 0.4681 * red)
    return 255 - min(max(Int(redOrGreen.rounded()), 0), 255)
}

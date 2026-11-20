import Testing
@testable import CVPipeline

@Suite("PhoneLens")
struct PhoneLensTests {
    @Test("a 90 degree view gives a zoom of 960, half the video's width")
    func rightAngle() throws {
        let lens = try #require(PhoneLens.lens(fieldOfView: 90))
        #expect(abs(lens.zoom - 960) <= 1e-9)
    }

    @Test("the 66.29 degree view that fits your checkerboard gives its zoom of 1470")
    func yourCheckerboard() throws {
        let lens = try #require(PhoneLens.lens(fieldOfView: 66.29))
        #expect(abs(lens.zoom - 1470.2) <= 0.5)
    }

    @Test("a wider 70 degree view gives a smaller zoom of 1371")
    func widerLens() throws {
        let lens = try #require(PhoneLens.lens(fieldOfView: 70))
        #expect(abs(lens.zoom - 1371.02) <= 0.01)
    }

    @Test("the lens center is the middle of the 1920 × 1080 video")
    func center() throws {
        for angle in [66.29, 70] {
            let lens = try #require(PhoneLens.lens(fieldOfView: angle))
            #expect(lens.centerX == 960)
            #expect(lens.centerY == 540)
        }
    }

    @Test("a phone that reports no angle gives no lens")
    func noAngle() {
        #expect(PhoneLens.lens(fieldOfView: 0) == nil)
    }
}

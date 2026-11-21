import Testing
@testable import CVPipeline

@Suite("ShotClipper")
struct ShotClipperTests {
    private let recording = 41.4

    private func expectClip(_ clip: (start: Double, end: Double), from start: Double, to end: Double) {
        #expect(abs(clip.start - start) <= 1e-9)
        #expect(abs(clip.end - end) <= 1e-9)
    }

    @Test("a shot 10 seconds in gets the clip from 7.8 to 11.3 seconds")
    func middle() {
        expectClip(ShotClipper.clip(shotAt: 10.0, videoLength: recording), from: 7.8, to: 11.3)
    }

    @Test("two shots a second apart each get their own full clip")
    func backToBack() {
        expectClip(ShotClipper.clip(shotAt: 10.0, videoLength: recording), from: 7.8, to: 11.3)
        expectClip(ShotClipper.clip(shotAt: 11.0, videoLength: recording), from: 8.8, to: 12.3)
    }

    @Test("a shot exactly 2.2 seconds in just fits, from 0 to 3.5 seconds")
    func justFitsAtStart() {
        expectClip(ShotClipper.clip(shotAt: 2.2, videoLength: recording), from: 0, to: 3.5)
    }

    @Test("a shot 1 second in starts at 0 and ends at 2.3 seconds")
    func tooEarly() {
        expectClip(ShotClipper.clip(shotAt: 1.0, videoLength: recording), from: 0, to: 2.3)
    }

    @Test("a shot 1.3 seconds before the end just fits, from 37.9 to 41.4 seconds")
    func justFitsAtEnd() {
        expectClip(ShotClipper.clip(shotAt: 40.1, videoLength: recording), from: 37.9, to: 41.4)
    }

    @Test("a shot 0.5 seconds before the end stops at the end, from 38.7 to 41.4 seconds")
    func tooLate() {
        expectClip(ShotClipper.clip(shotAt: 40.9, videoLength: recording), from: 38.7, to: 41.4)
    }
}

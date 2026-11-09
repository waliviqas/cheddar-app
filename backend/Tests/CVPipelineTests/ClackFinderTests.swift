import Testing
import Foundation
@testable import CVPipeline

@Suite("ClackFinder")
struct ClackFinderTests {

    /*
    - A loud, steady low hum (like skates or rink noise) goes in, 20 ms at a time
    - Low sounds get stripped out, so nothing should be found
    */
    @Test("a loud low hum is not a clack")
    func lowHumIsNotAClack() {
        var finder = ClackFinder()

        let hum = wave(hz: 100, seconds: 1, loudness: 0.5)

        #expect(feed(hum, into: &finder) == [])
    }

    /*
    - Quiet background with one short, high-pitched click at 0.5 s
    - Should find exactly one clack, at 0.5 s
    */
    @Test("a sharp click is found at the right time")
    func sharpClickIsFound() throws {
        var finder = ClackFinder()

        var sound = wave(hz: 4_000, seconds: 1, loudness: 0.005)
        sound.replaceSubrange(24_000..<24_096, with: wave(hz: 4_000, seconds: 0.002, loudness: 0.5))

        let clacks = feed(sound, into: &finder)

        #expect(clacks.count == 1)
        #expect(abs(try #require(clacks.first) - 0.5) < 0.002)
    }
}

// Fake sound: a steady tone at `hz`, `seconds` long, at 48,000 numbers a second.
private func wave(hz: Double, seconds: Double, loudness: Float) -> [Float] {
    (0..<Int(seconds * 48_000)).map { i in
        loudness * Float(sin(2 * Double.pi * hz * Double(i) / 48_000))
    }
}

// Gives the sound to ClackFinder in 20 ms packs like the mic does, and returns every clack time it reports.
private func feed(_ sound: [Float], into finder: inout ClackFinder) -> [Double] {
    let packSize = 960
    var clacks: [Double] = []
    for start in stride(from: 0, to: sound.count, by: packSize) {
        let pack = Array(sound[start..<min(start + packSize, sound.count)])
        clacks += finder.add(pack, startSeconds: Double(start) / 48_000)
    }
    return clacks
}

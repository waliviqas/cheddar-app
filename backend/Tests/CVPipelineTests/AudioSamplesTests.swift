import Testing
@testable import CVPipeline

@Suite("AudioSamples")
struct AudioSamplesTests {

    /*
    - Two small packs go in, one after the other
    - Every number should be kept, in the order it came in
    */
    @Test("keeps every number in order")
    func keepsEveryNumberInOrder() {
        var audio = AudioSamples()

        audio.add([1, 2, 3], startSeconds: 0)
        audio.add([4, 5, 6], startSeconds: 3.0 / 48_000)

        #expect(audio.samples == [1, 2, 3, 4, 5, 6])
    }

    /*
    - Packs of different lengths go in, each filled with its pack number
    - After every pack, only the newest 3 seconds should be kept, oldest first
    */
    @Test("keeps only the last 3 seconds as packs come in")
    func keepsLastThreeSeconds() {
        var audio = AudioSamples()

        audio.add(pack(1, seconds: 2), startSeconds: 0)
        #expect(layout(audio) == [Run(pack: 1, seconds: 2)])

        audio.add(pack(2, seconds: 0.5), startSeconds: 2)
        #expect(layout(audio) == [Run(pack: 1, seconds: 2), Run(pack: 2, seconds: 0.5)])

        audio.add(pack(3, seconds: 1), startSeconds: 2.5)
        #expect(layout(audio) == [Run(pack: 1, seconds: 1.5), Run(pack: 2, seconds: 0.5), Run(pack: 3, seconds: 1)])

        audio.add(pack(4, seconds: 2.5), startSeconds: 3.5)
        #expect(layout(audio) == [Run(pack: 3, seconds: 0.5), Run(pack: 4, seconds: 2.5)])
    }

    /*
    - Used by ClackFinder: turns a spot in the bucket into a real time
    - 5 seconds of sound go in, so the first 2 seconds leak out
    - The oldest sound left is from 2 s, so spot 0 = 2 s and spot 48,000 = 3 s
    */
    @Test("gives the right time for a spot after old sound leaks out")
    func timeAfterLeaking() {
        var audio = AudioSamples()

        audio.add(pack(1, seconds: 2), startSeconds: 0)
        audio.add(pack(2, seconds: 3), startSeconds: 2)

        #expect(audio.time(at: 0) == 2)
        #expect(audio.time(at: 48_000) == 3)
    }
}

// A fake pack of sound `seconds` long, every number set to the pack's number.
private func pack(_ number: Float, seconds: Double) -> [Float] {
    [Float](repeating: number, count: Int(seconds * 48_000))
}

private struct Run: Equatable {
    let pack: Float
    let seconds: Double
}

// Reads the bucket back as "pack 1 for 1.5 s, then pack 2 for 0.5 s, ...".
private func layout(_ audio: AudioSamples) -> [Run] {
    var runs: [(pack: Float, count: Int)] = []
    for number in audio.samples {
        if runs.last?.pack == number {
            runs[runs.count - 1].count += 1
        } else {
            runs.append((number, 1))
        }
    }
    return runs.map { Run(pack: $0.pack, seconds: Double($0.count) / 48_000) }
}

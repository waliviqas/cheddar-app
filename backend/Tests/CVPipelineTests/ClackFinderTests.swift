import Testing
import Foundation
import AVFoundation
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

    /*
    - Plays each of Wali's 5 rink clips into ClackFinder, 20 ms at a time, like the live mic
    - Answer sheet: the 12 shot times we measured
    - Every shot on the answer sheet must be in ClackFinder's list, within 10 ms
    - Extra sounds are fine; the camera throws those out later
    */
    @Test("finds every shot in the rink clips")
    func findsEveryShotInRinkClips() async throws {
        let answerSheet: [String: [Double]] = [
            "43mph-54mph": [8.401, 13.964],
            "54mph-52mph": [9.510, 16.645],
            "58mph-49mph": [9.452, 14.319],
            "43mph-49mph": [8.498, 13.291, 16.468],
            "47mph-52mph": [8.223, 12.556, 15.292],
        ]

        for (clip, shots) in answerSheet {
            var finder = ClackFinder()
            let found = feed(try await clipSound(clip), into: &finder)

            for shot in shots {
                #expect(found.contains { abs($0 - shot) < 0.01 }, "missed shot at \(shot) s in \(clip)")
            }
        }
    }
}

// The fake mic: pulls the sound out of a rink clip as numbers, 48,000 a second.
private func clipSound(_ clip: String) async throws -> [Float] {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("videos/rink-clips/1x-measured/\(clip).MOV")
    let asset = AVURLAsset(url: url)
    let track = try #require(try await asset.loadTracks(withMediaType: .audio).first)

    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 48_000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsFloatKey: true,
        AVLinearPCMIsNonInterleaved: false,
        AVLinearPCMIsBigEndianKey: false,
    ])
    reader.add(output)
    reader.startReading()

    var sound: [Float] = []
    while let buffer = output.copyNextSampleBuffer(), let block = CMSampleBufferGetDataBuffer(buffer) {
        let length = CMBlockBufferGetDataLength(block)
        var chunk = [Float](repeating: 0, count: length / 4)
        CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: &chunk)
        sound += chunk
    }
    return sound
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

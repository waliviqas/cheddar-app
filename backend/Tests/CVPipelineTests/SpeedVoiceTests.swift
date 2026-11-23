import Foundation
import Testing
#if os(iOS)
import AVFoundation
#endif
@testable import CVPipeline

// The sound tests need an iPhone (or its simulator), so they only run there.
@Suite("SpeedVoice", .serialized)
@MainActor
struct SpeedVoiceTests {
    // What it says

    @Test("61.4 mph is said as 61.4, the exact speed")
    func exactSpeed() {
        #expect(SpeedVoice.line(for: 61.4) == "61.4")
    }

    @Test("61.46 mph is said as 61.5, one decimal like the screen")
    func oneDecimal() {
        #expect(SpeedVoice.line(for: 61.46) == "61.5")
    }

    @Test("the slowest real shot, 5 mph, is said as 5.0")
    func slowestShot() {
        #expect(SpeedVoice.line(for: 5) == "5.0")
    }

    @Test("the fastest real shot, 130 mph, is said as 130.0")
    func fastestShot() {
        #expect(SpeedVoice.line(for: 130) == "130.0")
    }

    #if os(iOS)
    // Sound settings

    @Test("starting a session picks the playback sound mode, so a phone on silent still talks")
    func playbackMode() {
        SpeedVoice.shared.start()

        #expect(AVAudioSession.sharedInstance().category == .playback)
    }

    @Test("other apps' music keeps playing, just quieter, while it talks")
    func musicKeepsPlaying() {
        SpeedVoice.shared.start()
        let options = AVAudioSession.sharedInstance().categoryOptions

        #expect(options.contains(.mixWithOthers))
        #expect(options.contains(.duckOthers))
    }

    @Test("music gets its full volume back once the number is said")
    func givesSoundBack() async throws {
        SpeedVoice.shared.say([62.4])

        #expect(SpeedVoice.shared.holdsSound)
        try await waitUntil { !SpeedVoice.shared.holdsSound }
        #expect(SpeedVoice.shared.spoken.last == "62.4")
    }

    // Warming up

    @Test("starting a session makes 2 silent practice lines and plays nothing out loud")
    func practiceLines() async throws {
        let practice = SpeedVoice.shared.practiceLines, spoken = SpeedVoice.shared.spoken.count
        SpeedVoice.shared.start()
        try await Task.sleep(for: .seconds(2))

        #expect(SpeedVoice.shared.practiceLines == practice + 2)
        #expect(SpeedVoice.shared.spoken.count == spoken)
        #expect(!SpeedVoice.shared.holdsSound)
    }

    // Saying it

    @Test("two quick shots, 0.3 s apart, are both said, in order")
    func twoQuickShots() async throws {
        let before = SpeedVoice.shared.spoken.count
        SpeedVoice.shared.say([62.0])
        try await Task.sleep(for: .seconds(0.3))
        SpeedVoice.shared.say([58.0])
        try await waitUntil { SpeedVoice.shared.spoken.count >= before + 2 }

        #expect(Array(SpeedVoice.shared.spoken.dropFirst(before)) == ["62.0", "58.0"])
    }

    @Test("a number keeps going after the camera screen that asked for it closes")
    func outlivesTheScreen() async throws {
        var screen: CameraScreen? = CameraScreen()
        screen?.shot(71.3)
        screen = nil
        try await waitUntil { SpeedVoice.shared.spoken.last == "71.3" }

        #expect(screen == nil)
        #expect(SpeedVoice.shared.spoken.last == "71.3")
    }

    // Sound on from Record to Stop

    @Test("once recording starts, the sound stays on between numbers")
    func soundStaysOnBetweenNumbers() async throws {
        let voice = SpeedVoice.shared
        voice.startRecording()
        let before = voice.spoken.count
        voice.say([61.4])
        try await waitUntil { voice.spoken.count >= before + 1 }

        #expect(voice.holdsSound)
        voice.say([58.2])
        try await waitUntil { voice.spoken.count >= before + 2 }
        #expect(voice.holdsSound)
        voice.stopRecording()
    }

    @Test("starting a recording plays one silent line that isn't counted as a number")
    func silentLineAtRecord() async throws {
        let voice = SpeedVoice.shared
        let silent = voice.silentLines, spoken = voice.spoken.count
        voice.startRecording()
        try await Task.sleep(for: .seconds(2))

        #expect(voice.silentLines == silent + 1)
        #expect(voice.spoken.count == spoken)
        voice.stopRecording()
    }

    @Test("after Stop, with nothing left to say, the sound goes off")
    func soundOffAfterStop() {
        let voice = SpeedVoice.shared
        voice.startRecording()
        voice.stopRecording()

        #expect(!voice.holdsSound)
    }

    @Test("Stop in the middle of a number: the sound goes off once the number ends")
    func stopMidNumber() async throws {
        let voice = SpeedVoice.shared
        voice.startRecording()
        voice.say([62.4])
        voice.stopRecording()

        #expect(voice.holdsSound)
        try await waitUntil { !voice.holdsSound }
        #expect(voice.spoken.last == "62.4")
    }
    #endif
}

#if os(iOS)
// Stands in for the camera screen: it asks for a number and then goes away.
@MainActor
private final class CameraScreen {
    func shot(_ mph: Double) {
        SpeedVoice.shared.say([mph])
    }
}

@MainActor
private func waitUntil(seconds: Double = 15, _ condition: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(seconds)
    while !condition() {
        guard Date() < deadline else {
            Issue.record("waited \(seconds) s")
            return
        }
        try await Task.sleep(for: .milliseconds(50))
    }
}
#endif

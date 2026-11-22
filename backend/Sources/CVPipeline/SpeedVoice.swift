@preconcurrency import AVFoundation

/*
This class's only job is: say each shot's speed out loud, so the player hears it from where they shot.

It says the speed the way the screen shows it, with one decimal, in Apple's built-in voice. On an iPhone it plays even with
the side switch on silent, and other apps' music keeps playing, just quieter, while it talks.
*/
@MainActor
public final class SpeedVoice: NSObject, AVSpeechSynthesizerDelegate {
    // One for the whole app, so closing the camera screen doesn't cut a number off.
    public static let shared = SpeedVoice()

    private let voice = AVSpeechSynthesizer()
    private var speaking: Set<ObjectIdentifier> = []
    private(set) var spoken: [String] = []
    private(set) var practiceLines = 0
    private(set) var holdsSound = false

    private override init() {
        super.init()
        voice.delegate = self
    }

    public static func line(for mph: Double) -> String {
        String(format: "%.1f", mph)
    }

    // Sets the sound mode and makes 2 silent practice lines, because the voice's first line in a fresh app is slow.
    public func start() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers, .duckOthers])
        #endif
        for _ in 0..<2 {
            voice.write(utterance("0")) { @Sendable _ in }
            practiceLines += 1
        }
    }

    public func say(_ speeds: [Double]) {
        guard !speeds.isEmpty else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        holdsSound = true
        for mph in speeds {
            let line = utterance(Self.line(for: mph))
            speaking.insert(ObjectIdentifier(line))
            voice.speak(line)
        }
    }

    private func utterance(_ text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        return utterance
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance), text = utterance.speechString
        Task { @MainActor in self.finished(id, text) }
    }

    // Practice lines don't count. Other apps get their full volume back once there's nothing left to say.
    private func finished(_ id: ObjectIdentifier, _ text: String) {
        guard speaking.remove(id) != nil else { return }
        spoken.append(text)
        guard speaking.isEmpty else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        holdsSound = false
    }
}

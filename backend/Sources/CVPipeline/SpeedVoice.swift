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
    private(set) var silentLines = 0
    private var recording = false  // the sound stays on from Record to Stop

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

    // Recording started. When no other app is playing, the sound goes on now and stays on until Stop, so a number never
    // waits for it, and one silent line wakes the speaker (the practice lines only warm the voice). With music playing,
    // each number turns the sound on as before, so the music only dips while a number is said.
    public func startRecording() {
        #if os(iOS)
        let sound = AVAudioSession.sharedInstance()
        guard !sound.isOtherAudioPlaying, (try? sound.setActive(true)) != nil else { return }
        #endif
        recording = true
        holdsSound = true
        let silent = utterance("0")
        silent.volume = 0
        voice.speak(silent)
        silentLines += 1
    }

    // Recording stopped: the sound goes off once nothing is left to say.
    public func stopRecording() {
        guard recording else { return }
        recording = false
        guard speaking.isEmpty else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        holdsSound = false
    }

    public func say(_ speeds: [Double]) {
        guard !speeds.isEmpty else { return }
        #if os(iOS)
        if !recording { try? AVAudioSession.sharedInstance().setActive(true) }
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
        guard speaking.isEmpty, !recording else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        holdsSound = false
    }
}

import AVFoundation
import Observation

/*
This class's only job is: play a clip and say when each shot happens,
slowing down around the shot and revealing its speed right after the puck leaves the stick.
*/
@MainActor
@Observable
final class ShotPlayerModel {
    static let slowFrom = -0.3      // seconds around the clack that play in slow motion
    static let slowUntil = 0.6
    static let revealAt = 0.3       // seconds after the clack the speed pops up
    static let slowRate: Float = 0.2
    static let popSeconds = 3.0     // how long the big number stays up

    let clip: DemoClip
    let player: AVPlayer
    private(set) var isPlaying = false
    private(set) var finished = false
    private(set) var inSlowMotion = false
    private(set) var popped: DemoShot?
    private(set) var revealed: [DemoShot] = []
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    init(clip: DemoClip) {
        self.clip = clip
        let item = AVPlayerItem(url: clip.url)
        item.audioTimePitchAlgorithm = .spectral
        player = AVPlayer(playerItem: item)
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 120), queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time.seconds) }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isPlaying = false
                self?.finished = true
            }
        }
    }

    var topSpeed: Double? { revealed.compactMap(\.mph).max() }

    func togglePlay() {
        if finished {
            restart()
        } else if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.rate = inSlowMotion ? Self.slowRate : 1
            isPlaying = true
        }
    }

    func stop() {
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
    }

    private func restart() {
        revealed = []
        popped = nil
        finished = false
        inSlowMotion = false
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.player.rate = 1
                self?.isPlaying = true
            }
        }
    }

    private func tick(_ seconds: Double) {
        let slow = clip.shots.contains { seconds >= $0.time + Self.slowFrom && seconds < $0.time + Self.slowUntil }
        if slow != inSlowMotion {
            inSlowMotion = slow
            if isPlaying { player.rate = slow ? Self.slowRate : 1 }
        }
        for shot in clip.shots where seconds >= shot.time + Self.revealAt && !revealed.contains(where: { $0.id == shot.id }) {
            reveal(shot)
        }
    }

    private func reveal(_ shot: DemoShot) {
        revealed.append(shot)
        popped = shot
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.popSeconds))
            if self?.popped?.id == shot.id { self?.popped = nil }
        }
    }
}

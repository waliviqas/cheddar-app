import AVFoundation
import Observation

/*
This class's only job is: run a session like the camera is live —
hear each shot, take a moment to read it, then reveal its speed, and hand back the finished session.
*/
@MainActor
@Observable
final class LiveSessionModel {
    static let readSeconds = 1.3    // how long "reading the shot" takes after the clack
    static let popSeconds = 3.2     // how long the big number stays up

    let player: AVPlayer
    let shots = Demo.liveShots
    private(set) var started = false
    private(set) var isPlaying = false
    private(set) var finished = false
    private(set) var wrappingUp = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var reading: Shot?
    private(set) var popped: Shot?
    private(set) var revealed: [Shot] = []
    private var heard: Set<Int> = []
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    init() {
        let item = AVPlayerItem(url: Demo.sessionVideo)
        player = AVPlayer(playerItem: item)
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 60), queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time.seconds) }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.finishAfterLastShot() }
        }
    }

    var topSpeed: Double? { revealed.compactMap(\.mph).max() }

    func start() {
        started = true
        isPlaying = true
        player.play()
    }

    func togglePause() {
        guard started, !finished else { return }
        isPlaying ? player.pause() : player.play()
        isPlaying.toggle()
    }

    func end() {
        guard !finished else { return }
        player.pause()
        isPlaying = false
        finished = true
    }

    // When the feed runs out, hold on the last frame so the last shot's number stays up a moment.
    private func finishAfterLastShot() {
        isPlaying = false
        wrappingUp = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            self?.end()
        }
    }

    // The session as it stands: every shot read so far.
    func session() -> Session {
        Session(date: .now, cover: "SessionLive", shots: revealed, duration: elapsed)
    }

    func stop() {
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
    }

    private func tick(_ seconds: Double) {
        elapsed = seconds
        for shot in shots where seconds >= shot.clack && !heard.contains(shot.id) {
            heard.insert(shot.id)
            reading = shot
        }
        for shot in shots where seconds >= shot.clack + Self.readSeconds && !revealed.contains(where: { $0.id == shot.id }) {
            reveal(shot)
        }
    }

    private func reveal(_ shot: Shot) {
        if reading?.id == shot.id { reading = nil }
        revealed.append(shot)
        popped = shot
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.popSeconds))
            if self?.popped?.id == shot.id { self?.popped = nil }
        }
    }
}

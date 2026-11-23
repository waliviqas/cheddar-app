import CoreVideo
import Foundation

/*
This class's only job is: while the player films, hand each camera frame to the live reader and say each speed out loud
the moment it's read, then after Stop hand back the session's shots: each shot said live keeps its live reading, and the
after-Stop reading fills in any shot it never said.

Reading starts on the frame 1 s in, where the after-Stop reader finds the net, past the wobble from tapping record. The
camera hands frames over on its own background line. The voice lives on the main line, so speeds are passed there.
*/
public final class LiveSpeeds: @unchecked Sendable {
    private let makeReader: (CVPixelBuffer) -> LiveShotReader?
    private let netFrameTime: Double  // seconds into the video of the frame the live reader starts on
    private let say: @MainActor @Sendable ([Double]) -> Void
    private let lock = NSLock()
    // The speed math (about 15-20 ms a shot) runs here, so the camera's line never waits on it and drops frames.
    private let fitLine = DispatchQueue(label: "cheddar.fits", qos: .userInitiated)
    private var started = false, stopped = false, triedReader = false
    private var zero: Double?  // the video's first frame on the phone's clock
    private var reader: LiveShotReader?
    private var saidReadings: [ShotReading] = []
    private var handedOver = 0

    public convenience init(taps: [Vec2], lens: Lens,
                            say: @escaping @MainActor @Sendable ([Double]) -> Void = { SpeedVoice.shared.say($0) }) {
        self.init(say: say, netFrameTime: ShotReader.netFrameTime) { LiveShotReader(netFrame: $0, taps: taps, lens: lens, readsLater: true) }
    }

    init(say: @escaping @MainActor @Sendable ([Double]) -> Void, netFrameTime: Double = 0,
         makeReader: @escaping (CVPixelBuffer) -> LiveShotReader?) {
        self.say = say
        self.netFrameTime = netFrameTime
        self.makeReader = makeReader
    }

    // When each shot said live left the stick, in seconds into the video, once the speed math in progress is done.
    var said: [Double] {
        fitLine.sync {}
        return lock.withLock { saidReadings.map(\.releaseTime) }
    }

    // Every shot said out loud so far, in order, for saving the session right after Stop without reading the video again.
    // It waits for the speed math in progress, so a shot decided just before Stop is in it.
    public var readings: [ShotReading] {
        fitLine.sync {}
        return lock.withLock { saidReadings }
    }

    // How many shots have been handed to the speed math, for checking the camera's line never waits on it.
    var decisions: Int { lock.withLock { handedOver } }

    // The net's corners the live reader found, once it has started.
    var corners: [Vec2] { lock.withLock { reader?.corners ?? [] } }

    // The video started. videoStart is its first frame on the phone's clock when the phone says (iOS 18.2 and newer);
    // without it, the video's time counts from the next frame.
    public func start(videoStart: Double?) {
        lock.withLock {
            started = true
            zero = videoStart
        }
    }

    // A camera frame, filmed at this time on the phone's clock. Frames come one at a time, in order.
    public func frame(_ frame: CVPixelBuffer, time: Double) {
        lock.lock()
        defer { lock.unlock() }
        guard started, !stopped else { return }
        if let zero, time < zero - 1e-6 { return }
        let zero = self.zero ?? time
        self.zero = zero
        if !triedReader {
            guard time - zero >= netFrameTime - 1e-6 else { return }  // a shot this early is said after Stop
            triedReader = true
            reader = makeReader(frame)
        }
        guard let readings = reader?.feed(frame, time: time - zero) else { return }
        if let decided = reader?.takeDecided(), !decided.isEmpty, let fitter = reader?.fitter {
            handedOver += decided.count
            fitLine.async { self.read(decided, with: fitter) }
        }
        guard !readings.isEmpty else { return }
        saidReadings += readings
        let speeds = readings.map(\.mph), say = self.say
        DispatchQueue.main.async { MainActor.assumeIsolated { say(speeds) } }
    }

    // Reads decided shots off the camera's line and says the ones safe to say. A shot decided before Stop is kept and said
    // even when its speed comes in just after.
    private func read(_ decided: [ShotLogic.Decided], with fitter: ShotLogic.Fitter) {
        let readings = decided.map(fitter.note).filter(\.said).compactMap(\.reading)
        guard !readings.isEmpty else { return }
        lock.withLock {
            saidReadings += readings
            let speeds = readings.map(\.mph), say = self.say
            DispatchQueue.main.async { MainActor.assumeIsolated { say(speeds) } }
        }
    }

    // A frame the camera dropped: any shot it was in isn't said live.
    public func dropped() {
        lock.withLock {
            guard started, !stopped else { return }
            reader?.noteDropped()
        }
    }

    // Filming stopped. Frames still coming from the camera are ignored.
    public func stop() {
        lock.withLock { stopped = true }
    }

    // After Stop: the shots read from the saved video that weren't said live, to say now.
    public func missed(_ afterStop: [ShotReading]) -> [ShotReading] {
        Self.missed(afterStop, said: said)
    }

    // After Stop: the session's shots, in time order.
    public func saved(_ afterStop: [ShotReading]) -> [ShotReading] {
        Self.saved(afterStop, live: readings)
    }

    // Readings less than 0.3 s apart are the same shot, the window the shot finder joins a shot's pieces within.
    static func missed(_ afterStop: [ShotReading], said: [Double]) -> [ShotReading] {
        afterStop.filter { reading in !said.contains { abs($0 - reading.releaseTime) < ShotFinder.sameShotWindow } }
    }

    // Each shot said live keeps its live reading, so what's kept is what was said; the after-Stop reading fills in the rest.
    static func saved(_ afterStop: [ShotReading], live: [ShotReading]) -> [ShotReading] {
        (live + missed(afterStop, said: live.map(\.releaseTime))).sorted { $0.releaseTime < $1.releaseTime }
    }
}

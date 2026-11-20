import AVFoundation
import CVPipeline
import Foundation
import Observation

/*
This class's only job is: run the record screen's story — placing the net's 4 corners, filming the session, reading
every shot in it, and handing back the session.
*/
@MainActor
@Observable
final class RecordViewModel {
    enum Phase {
        case tapping    // placing the net's 4 corners
        case ready      // corners set; the record button is up
        case recording
        case analyzing
        case noShots
    }

    private(set) var phase: Phase = .tapping
    private(set) var cameraReady = false
    private(set) var taps: [CGPoint] = []  // where the player put the net's corners, in screen points
    private var screen = CGSize.zero
    let recorder = ShotRecorder()
    private let onSession: (Session) -> Void

    init(onSession: @escaping (Session) -> Void) {
        self.onSession = onSession
    }

    // The corners on the screen, top-left, top-right, bottom-right, bottom-left, once all 4 are in.
    var outline: [CGPoint]? {
        ScreenTaps.ordered(taps.map { Vec2($0.x, $0.y) })?.map { CGPoint(x: $0.x, y: $0.y) }
    }

    // The net's corners in the video, once all 4 are in.
    private var corners: [Vec2]? {
        ScreenTaps.corners(taps.map { Vec2($0.x, $0.y) }, screen: Vec2(screen.width, screen.height))
    }

    // Turns the camera on when the screen appears.
    func start() async {
        cameraReady = await recorder.start()
    }

    // Adds a corner where the player tapped, up to 4.
    func tap(_ spot: CGPoint, screen: CGSize) {
        guard phase == .tapping, taps.count < 4 else { return }
        taps.append(spot)
        self.screen = screen
    }

    // Moves the corner the player is dragging.
    func move(_ index: Int, to spot: CGPoint) {
        guard phase == .tapping, taps.indices.contains(index) else { return }
        taps[index] = spot
    }

    // Takes back the last corner.
    func undo() {
        guard phase == .tapping, !taps.isEmpty else { return }
        taps.removeLast()
    }

    // The player's check: the corners are set, so the record button comes up.
    func confirmCorners() {
        guard phase == .tapping, taps.count == 4 else { return }
        phase = .ready
    }

    // Starts filming the session.
    func record() {
        phase = .recording
        recorder.beginRecording { [weak self] url in
            if let url {
                self?.analyze(url)
            } else {
                self?.reset()
            }
        }
    }

    // Stops filming; reading begins once the file is sealed.
    func stopRecording() {
        recorder.endRecording()
    }

    // Turns the camera off when the screen goes away.
    func stop() {
        recorder.stop()
    }

    // Reads every shot in the recording, discards the video, and hands back the session, or says no shots were found.
    private func analyze(_ url: URL) {
        phase = .analyzing
        Task {
            let length = (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0
            var readings: [ShotReading]?
            if let corners, let lens = PhoneLens.lens(fieldOfView: recorder.fieldOfView) {
                readings = try? await ShotReader.read(url, taps: corners, lens: lens)
            }
            try? FileManager.default.removeItem(at: url)
            let shots = (readings ?? []).enumerated().map { number, reading in
                Shot(id: number + 1, mph: reading.mph, square: NetGrid.square(across: reading.hit.x, up: reading.hit.y),
                     clack: reading.releaseTime)
            }
            if shots.isEmpty {
                phase = .noShots
            } else {
                onSession(Session(date: .now, shots: shots, duration: length))
            }
        }
    }

    // Back to the record button with the same corners, so the player can film again.
    func reset() {
        phase = .ready
    }
}

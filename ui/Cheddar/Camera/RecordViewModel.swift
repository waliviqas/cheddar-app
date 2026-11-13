import Foundation
import Observation

/*
This class's only job is: run the record screen's story — waiting, filming, thinking, showing the number.
*/
@MainActor
@Observable
final class RecordViewModel {
    enum Phase {
        case idle
        case recording
        case analyzing
        case result(Double?)
    }

    private(set) var phase: Phase = .idle
    private(set) var cameraReady = false
    let recorder = ShotRecorder()

    // Turns the camera on when the screen appears.
    func start() async {
        cameraReady = await recorder.start()
    }

    // Starts filming the shot.
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

    // Stops filming; analysis begins once the file is sealed.
    func stopRecording() {
        recorder.endRecording()
    }

    // Turns the camera off when the screen goes away.
    func stop() {
        recorder.stop()
    }

    // Sends the finished video through the CVPipeline backend, keeps the answer, and discards the clip.
    private func analyze(_ url: URL) {
        phase = .analyzing
        Task {
            let mph = (try? await ShotSpeedReader().mph(from: url)) ?? nil
            try? FileManager.default.removeItem(at: url)
            phase = .result(mph)
        }
    }

    // Forgets the last shot so another one can be filmed.
    func reset() {
        phase = .idle
    }
}

import AVFoundation

/*
This class's only job is: run the camera in 240fps slow motion and record shots to a file.
*/
final class ShotRecorder: NSObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    private let output = AVCaptureMovieFileOutput()
    private var finished: ((URL?) -> Void)?

    // Asks permission, wires the camera, and waits until it is truly running before saying ready.
    func start() async -> Bool {
        guard await AVCaptureDevice.requestAccess(for: .video) else { return false }
        guard configure() else { return false }
        let session = self.session
        await Task.detached { session.startRunning() }.value
        return session.isRunning
    }

    // Turns the camera off and abandons any recording still in progress.
    func stop() {
        finished = nil
        if output.isRecording {
            output.stopRecording()
        }
        let session = self.session
        Task.detached { session.stopRunning() }
    }

    // Starts writing what the camera sees to a fresh file; hands back nil if the recording fails.
    func beginRecording(onFinish: @escaping (URL?) -> Void) {
        finished = onFinish
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        output.startRecording(to: url, recordingDelegate: self)
    }

    // Stops writing; the system calls back once the file is sealed.
    func endRecording() {
        output.stopRecording()
    }

    // Called by the camera when the movie file is finished being written, cleanly or not.
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        let fileIsUsable = error == nil
            || ((error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true)
        DispatchQueue.main.async {
            self.finished?(fileIsUsable ? outputFileURL : nil)
        }
    }

    // Wires the back camera into the session and switches it into slow-motion mode.
    private func configure() -> Bool {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else { return false }
        session.beginConfiguration()
        session.sessionPreset = .inputPriority
        guard session.canAddInput(input), session.canAddOutput(output) else {
            session.commitConfiguration()
            return false
        }
        session.addInput(input)
        session.addOutput(output)
        applyFastestFrameRate(to: camera)
        session.commitConfiguration()
        return true
    }

    // Switches the camera into its 240fps mode, or the fastest mode it has.
    private func applyFastestFrameRate(to camera: AVCaptureDevice) {
        let slowMotionCapable = camera.formats.filter { maxRate($0) >= 240 }
        guard let format = slowMotionCapable.last ?? camera.formats.max(by: { maxRate($0) < maxRate($1) }) else { return }
        let rate = min(240, maxRate(format))
        do { try camera.lockForConfiguration() } catch { return }
        camera.activeFormat = format
        camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Int32(rate))
        camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: Int32(rate))
        camera.unlockForConfiguration()
    }

    // Reads the fastest frame rate a camera mode supports.
    private func maxRate(_ format: AVCaptureDevice.Format) -> Double {
        format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
    }
}

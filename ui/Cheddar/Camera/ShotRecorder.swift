import AVFoundation

/*
This class's only job is: run the camera in 1920 × 1080, 240fps slow motion and record shots to a file.
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
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(0) {
            connection.videoRotationAngle = 0  // sideways, top of the phone to the left, like the rink clips
        }
        let locked = lockSlowMotion(camera)
        session.commitConfiguration()
        return locked
    }

    // Switches the camera to 1920 × 1080 at 240fps, the only size and speed the shot reader works on. A phone that
    // can't gets no camera rather than clips the reader would misread.
    private func lockSlowMotion(_ camera: AVCaptureDevice) -> Bool {
        let fullHD = camera.formats.filter {
            let size = $0.formatDescription.dimensions
            return size.width == 1920 && size.height == 1080
        }
        guard let format = fullHD.last(where: { maxRate($0) >= 240 }) else { return false }
        do { try camera.lockForConfiguration() } catch { return false }
        camera.activeFormat = format
        camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 240)
        camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 240)
        camera.unlockForConfiguration()
        return true
    }

    // Reads the fastest frame rate a camera mode supports.
    private func maxRate(_ format: AVCaptureDevice.Format) -> Double {
        format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
    }
}

import AVFoundation
import CVPipeline

/*
This class's only job is: run the camera in 1920 × 1080, 240fps slow motion, record shots to a file, and hand each frame
to the live reader while it records.
*/
final class ShotRecorder: NSObject, AVCaptureFileOutputRecordingDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private(set) var fieldOfView = 0.0  // how wide the camera sees across the video, in degrees; 0 until it's locked
    private let output = AVCaptureMovieFileOutput()
    private let frames = AVCaptureVideoDataOutput()
    private let frameLine = DispatchQueue(label: "cheddar.frames")
    private var live: LiveSpeeds?  // only touched on frameLine
    private var waitingForFrame: (id: Int, done: (CVPixelBuffer?) -> Void)?  // only touched on frameLine
    private var frameRequests = 0  // only touched on frameLine
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
        frameLine.async { self.live = nil }
        if output.isRecording {
            output.stopRecording()
        }
        let session = self.session
        Task.detached { session.stopRunning() }
    }

    // Starts writing what the camera sees to a fresh file and handing each frame to the live reader; hands back nil if
    // the recording fails.
    func beginRecording(live: LiveSpeeds?, onFinish: @escaping (URL?) -> Void) {
        finished = onFinish
        frameLine.async { self.live = live }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        output.startRecording(to: url, recordingDelegate: self)
    }

    // Stops writing; the system calls back once the file is sealed.
    func endRecording() {
        frameLine.async { self.live = nil }
        output.stopRecording()
    }

    // Called by the camera once the movie file has started. On iOS 18.2 and newer the next one is called instead, with the
    // time of the video's first frame.
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        frameLine.async { self.live?.start(videoStart: nil) }
    }

    @available(iOS 18.2, *)
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, startPTS: CMTime,
                    from connections: [AVCaptureConnection]) {
        let videoStart = startPTS.isNumeric ? startPTS.seconds : nil
        frameLine.async { self.live?.start(videoStart: videoStart) }
    }

    // Hands the next camera frame to `done` on frameLine, for snapping the net while the player sets it up. Nil when the
    // phone can't hand frames over or none comes within half a second.
    func nextFrame(_ done: @escaping (CVPixelBuffer?) -> Void) {
        let handsOverFrames = session.outputs.contains(frames)
        frameLine.async {
            guard handsOverFrames else { return done(nil) }
            self.waitingForFrame?.done(nil)
            self.frameRequests += 1
            let id = self.frameRequests
            self.waitingForFrame = (id, done)
            self.frameLine.asyncAfter(deadline: .now() + 0.5) {
                guard let waiting = self.waitingForFrame, waiting.id == id else { return }
                self.waitingForFrame = nil
                waiting.done(nil)
            }
        }
    }

    // Called by the camera with each frame, on frameLine.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        if let waiting = waitingForFrame {
            waitingForFrame = nil
            waiting.done(frame)
        }
        live?.frame(frame, time: CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds)
    }

    // Called by the camera when it skipped a frame because the one before was still being read.
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        live?.dropped()
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
        if locked { addFrames(camera) }
        session.commitConfiguration()
        if session.outputs.contains(frames), session.hardwareCost > 1 {
            // Too much for this phone at once: keep recording, and speeds are only said after Stop.
            session.beginConfiguration()
            session.removeOutput(frames)
            session.commitConfiguration()
        }
        return locked
    }

    // Hands every frame to frameLine in the camera's own 420 format, the same way up as the video.
    private func addFrames(_ camera: AVCaptureDevice) {
        guard session.canAddOutput(frames) else { return }
        session.addOutput(frames)
        let native = CMFormatDescriptionGetMediaSubType(camera.activeFormat.formatDescription)
        let format = native == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange ? native : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        frames.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: format]
        frames.alwaysDiscardsLateVideoFrames = true
        frames.setSampleBufferDelegate(self, queue: frameLine)
        if let connection = frames.connection(with: .video), connection.isVideoRotationAngleSupported(0) {
            connection.videoRotationAngle = 0
        }
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
        fieldOfView = Double(format.videoFieldOfView)
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

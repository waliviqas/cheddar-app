import CoreVideo

/*
This class's only job is: take each camera frame as it arrives and hand back the speeds that are safe to say right now.

FastFramesBack finds the spots and ShotLogic reads the shots. The camera says when a frame never arrived, and those losses go
to ShotLogic, which holds back any shot they could have changed.
*/
struct LiveShotReader {
    private var finder: FastFramesBack
    private var logic: ShotLogic
    private var lastFrame = -Double.infinity
    private var lostSinceLast = 0
    private(set) var corners: [Vec2] = []  // the net's corners, once moved onto the posts in the net frame

    init(lane: (rows: Range<Int>, columns: Range<Int>), pose: CameraPose, scale: Double) {
        finder = FastFramesBack(rows: lane.rows, columns: lane.columns, scale: scale)
        logic = ShotLogic(pose: pose, scale: scale, laneX: Double(lane.columns.lowerBound)...Double(lane.columns.upperBound))
    }

    // Starts from the frame ShotReader.netFrameTime into the video, the one ShotReader.read uses: moves the taps onto the
    // posts (keeping them as tapped when the posts can't be found), places the phone and picks the strip to search. No
    // answer means the taps can't be a net.
    init?(netFrame: CVPixelBuffer, taps: [Vec2], lens: Lens) {
        CVPixelBufferLockBaseAddress(netFrame, .readOnly)
        let picture = Picture(frame: netFrame)
        CVPixelBufferUnlockBaseAddress(netFrame, .readOnly)
        let corners = NetCorners.refine(taps, picture: picture) ?? taps
        guard let pose = CameraPose(corners: corners, lens: lens) else { return nil }
        self.init(lane: ShotReader.lane(corners: corners, pose: pose), pose: pose, scale: ShotReader.netScale(corners))
        self.corners = corners
    }

    // Every shot so far, said out loud or held back, for comparing with the after-Stop read.
    var notes: [ShotLogic.Note] { logic.notes }

    // Call when the camera drops a frame, or whenever a frame never reaches feed.
    mutating func noteDropped(_ count: Int = 1) {
        lostSinceLast += count
    }

    // One full-size camera frame, 420 or red-green-blue. Gives the speeds that are safe to say now.
    mutating func feed(_ frame: CVPixelBuffer, time: Double) -> [ShotReading] {
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        let spots = finder.add(frame, time: time)
        CVPixelBufferUnlockBaseAddress(frame, .readOnly)
        return step(spots, time)
    }

    // The same, with the strip's darkness already made by FastFramesBack.storeDarkness.
    mutating func feed(darkness: UnsafePointer<UInt8>, time: Double) -> [ShotReading] {
        step(finder.add(darkness: darkness, time: time), time)
    }

    private mutating func step(_ spots: SpotFrame?, _ time: Double) -> [ShotReading] {
        if lostSinceLast > 0 {
            logic.noteGap(from: lastFrame, to: time, lost: lostSinceLast)
            lostSinceLast = 0
        }
        lastFrame = time
        guard let spots else { return [] }
        let before = logic.notes.count
        logic.feed(spots, frameTime: time)
        return logic.notes[before...].filter(\.said).compactMap(\.reading)
    }
}

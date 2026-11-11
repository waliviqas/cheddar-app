import AVFoundation
import CoreGraphics
import Foundation

/*
This class's only job is: take a video and where the camera is, and hand back every shot in it: when, how fast, and
which square of the net.
*/
public struct ClackShotReader {
    public struct Shot {
        public let clackTime: Double          // seconds into the video when the stick hit the puck (sound delay taken off)
        public let startSpot: CGPoint         // where the shot puck sat at the clack, pixels from the top-left, y down
        public let mph: Double?               // how fast it left the stick; nil when Cheddar couldn't read it
        public let square: NetSquare?         // where it crossed the goal line; nil when Cheddar couldn't read it
    }

    static let soundDelay = 0.0175            // the clack reaches the phone about this late (about 20 ft away)
    static let followFor = 0.45               // seconds of video after the clack: long enough to reach the net
    static let minimumFlight: CGFloat = 150   // pixels the puck has to travel to count as a shot, not just a sound
    static let stillWiggle: CGFloat = 6       // a resting puck's spot can jitter this much without having moved
    static let firstMoveLimit: CGFloat = 60   // the shot puck's first move is the blade pushing it: never a bigger jump

    private let pose: CameraPose
    private let lens: LensInfo
    private let releaseFinder: ReleaseFinder

    public init(pose: CameraPose, lens: LensInfo, openAIKey: String, send: @escaping ReleaseFinder.Send = ReleaseFinder.overInternet) {
        self.pose = pose
        self.lens = lens
        releaseFinder = ReleaseFinder(apiKey: openAIKey, send: send)
    }

    public func shots(in video: URL) async throws -> [Shot] {
        var shots: [Shot] = []
        for heard in try await clacks(in: video) {
            let clack = heard - Self.soundDelay
            // One clack can be heard twice; a shot is still in the air for a while after its clack.
            if let last = shots.last, clack - last.clackTime < Self.followFor { continue }
            if let shot = try await read(video, at: clack) { shots.append(shot) }
        }
        return shots
    }

    // One shot: find the puck that flies, when it left the stick, how fast, and where it crossed.
    // Nil when nothing flies after the clack (the sound wasn't a shot).
    private func read(_ video: URL, at clack: Double) async throws -> Shot? {
        let frames = try await VideoFrameExtractor().frames(from: video, between: clack, and: clack + Self.followFor)
        guard let first = frames.first else { return nil }
        let times = frames.map { $0.seconds - first.seconds }
        let detector = PuckDetector()
        func follow(from spot: CGPoint) -> [CGPoint?] {
            PuckLinker().path(from: spot, times: times) { i, around in detector.pucks(in: frames[i].image, near: around) }
        }

        // The shot puck is the one that flies the farthest from where it sat; a still puck or tape goes nowhere.
        // A still puck next to the shot can get followed onto the shot as it flies past, so a flight only counts if
        // it starts with a small move (the blade pushing the puck), not a big jump onto someone else's puck.
        let height = CGFloat(first.image.height)
        let candidates = detector.pucks(in: first.image).map { CGPoint(x: $0.midX, y: height - $0.midY) }
        let flights = candidates.map { start in (start: start, path: follow(from: start)) }
        func travel(_ f: (start: CGPoint, path: [CGPoint?])) -> CGFloat {
            let away = f.path.compactMap { $0 }.map { hypot($0.x - f.start.x, $0.y - f.start.y) }
            guard let firstMove = away.first(where: { $0 > Self.stillWiggle }), firstMove <= Self.firstMoveLimit else { return 0 }
            return away.max() ?? 0
        }
        guard let shot = flights.max(by: { travel($0) < travel($1) }), travel(shot) >= Self.minimumFlight else { return nil }

        // From here on, anything Cheddar can't read means no speed, never a guess.
        let ask = min(40, frames.count)
        guard let release = try await releaseFinder.releaseTime(in: Array(frames.prefix(ask)), path: Array(shot.path.prefix(ask))),
              let flight = ShotFlight(path: shot.path, times: times, releaseTime: release - first.seconds, pose: pose, lens: lens)
        else { return Shot(clackTime: clack, startSpot: shot.start, mph: nil, square: nil) }
        let square = NetGrid(pose: pose, lens: lens).square(across: flight.crossingSpot.x, up: flight.crossingSpot.y)
        return Shot(clackTime: clack, startSpot: shot.start, mph: flight.releaseMph, square: square)
    }

    // Plays the video's sound into ClackFinder 20 ms at a time, like the live mic, and returns every clack it hears.
    private func clacks(in video: URL) async throws -> [Double] {
        let asset = AVURLAsset(url: video)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return [] }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false,
        ])
        reader.add(output)
        reader.startReading()
        var sound: [Float] = []
        while let buffer = output.copyNextSampleBuffer(), let block = CMSampleBufferGetDataBuffer(buffer) {
            let length = CMBlockBufferGetDataLength(block)
            var chunk = [Float](repeating: 0, count: length / 4)
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: &chunk)
            sound += chunk
        }

        var finder = ClackFinder()
        var heard: [Double] = []
        for start in stride(from: 0, to: sound.count, by: 960) {
            heard += finder.add(Array(sound[start..<min(start + 960, sound.count)]), startSeconds: Double(start) / 48_000)
        }
        return heard
    }
}

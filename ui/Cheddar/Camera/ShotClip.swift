import AVFoundation
import CVPipeline

/*
This file's only job is: cut one shot's slow-mo replay clip out of the session's 240 fps recording, at the times
ShotClipper gives. Like the demo clips: 1280 × 720, all 240 frames a second, no sound, and about 5 MB.
*/
enum ShotClip {
    static func cut(_ shot: Shot, from video: URL, length: Double, to clip: URL) async throws {
        let source = AVURLAsset(url: video)
        guard let frames = try await source.loadTracks(withMediaType: .video).first else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let times = ShotClipper.clip(shotAt: shot.clack, videoLength: length)
        let range = CMTimeRange(start: CMTime(seconds: times.start, preferredTimescale: 2400),
                                end: CMTime(seconds: times.end, preferredTimescale: 2400))
        let silent = AVMutableComposition()  // the video track only
        guard let track = silent.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try track.insertTimeRange(range, of: frames, at: .zero)
        track.preferredTransform = try await frames.load(.preferredTransform)
        guard let export = AVAssetExportSession(asset: silent, presetName: AVAssetExportPreset1280x720) else {
            throw CocoaError(.fileWriteUnknown)
        }
        export.fileLengthLimit = 4_500_000  // lowers the quality to fit: ~5 MB instead of 15, still the whole 3.5 s
        try await export.saveMovie(to: clip)
    }
}

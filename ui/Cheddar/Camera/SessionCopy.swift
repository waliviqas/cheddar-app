import AVFoundation

/*
This file's only job is: make the small copy of a session's video that gets kept: 30 frames a second instead of 240,
at 960 × 540. On a 41-second rink clip that's 36 MB a minute instead of 381, made in about 4 seconds on a Mac. It
plays at normal speed, like the original.
*/
enum SessionCopy {
    static func make(from video: URL, to copy: URL) async throws {
        let asset = AVURLAsset(url: video)
        let thirtyFrames = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: asset)
        thirtyFrames.sourceTrackIDForFrameTiming = kCMPersistentTrackID_Invalid  // otherwise it keeps all 240
        thirtyFrames.frameDuration = CMTime(value: 1, timescale: 30)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset960x540) else {
            throw CocoaError(.fileWriteUnknown)
        }
        export.videoComposition = thirtyFrames
        if #available(iOS 18, macOS 15, *) {
            try await export.export(to: copy, as: .mov)
        } else {
            export.outputURL = copy
            export.outputFileType = .mov
            await export.export()
            if let error = export.error { throw error }
        }
    }
}

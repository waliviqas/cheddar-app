import AVFoundation

/*
This file's only job is: save a video export as a .mov file, the iOS 18 way when the phone has it.
*/
extension AVAssetExportSession {
    func saveMovie(to file: URL) async throws {
        if #available(iOS 18, macOS 15, *) {
            try await export(to: file, as: .mov)
        } else {
            outputURL = file
            outputFileType = .mov
            await export()
            if let error { throw error }
        }
    }
}

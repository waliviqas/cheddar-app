import AVFoundation
import SwiftUI

/*
This view's only job is: show a still from a session's video at the top of its card, taken at the first shot and saved
once so the list stays quick.
*/
struct SessionCover: View {
    let session: Session
    @State private var picture: UIImage?

    var body: some View {
        Color.white.opacity(0.06)
            .overlay {
                if let picture {
                    Image(uiImage: picture).resizable().scaledToFill()
                }
            }
            .task(id: session.id) { picture = await Self.picture(for: session) }
    }

    private static let folder = URL.cachesDirectory.appending(path: "SessionCovers", directoryHint: .isDirectory)

    // The saved still, or a new one from the video, brought back from iCloud first when it's only there.
    private static func picture(for session: Session) async -> UIImage? {
        let file = folder.appending(path: "\(session.id).jpg")
        if let saved = UIImage(contentsOfFile: file.path) { return saved }
        guard let url = session.video.flatMap(SavedVideos.url) else { return nil }
        await SavedVideos.download(url)
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 900, height: 900)
        let time = CMTime(seconds: session.shots.first?.clack ?? 1, preferredTimescale: 600)
        guard let still = try? await generator.image(at: time).image else { return nil }
        let picture = UIImage(cgImage: still)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? picture.jpegData(compressionQuality: 0.8)?.write(to: file)
        return picture
    }
}

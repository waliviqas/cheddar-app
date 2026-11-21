import SwiftUI

/*
This view's only job is: make sure a saved video is on the phone before it plays. A video kept in iCloud shows a
spinner while it comes back to the phone, then the player.
*/
struct DownloadedVideo<Player: View>: View {
    let url: URL
    let player: (URL) -> Player
    @State private var ready: Bool
    @Environment(\.dismiss) private var dismiss

    init(url: URL, @ViewBuilder player: @escaping (URL) -> Player) {
        self.url = url
        self.player = player
        _ready = State(initialValue: SavedVideos.isOnPhone(url))
    }

    var body: some View {
        if ready {
            player(url)
        } else {
            ZStack(alignment: .topLeading) {
                Color.black.ignoresSafeArea()
                ProgressView("Getting your video from iCloud…")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Same close button as the camera and the shot replay.
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(16)
            }
            .task {
                await SavedVideos.download(url)
                ready = true
            }
        }
    }
}

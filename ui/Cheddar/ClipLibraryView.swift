import AVFoundation
import SwiftUI

/*
This screen's only job is: show the user's clips so they can pick one to play.
*/
struct ClipLibraryView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(DemoClip.all) { clip in
                        NavigationLink {
                            ShotPlayerView(clip: clip)
                        } label: {
                            ClipCard(clip: clip)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Your Shots")
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// One clip: a still from the video with a play button, and how many shots are in it.
private struct ClipCard: View {
    let clip: DemoClip
    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Color.black
                if let thumbnail {
                    Image(uiImage: thumbnail).resizable().scaledToFill()
                }
                Image(systemName: "play.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.navy)
                    .frame(width: 56, height: 56)
                    .background(Theme.cheddar, in: Circle())
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipped()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(clip.title).font(.headline).foregroundStyle(.white)
                    Text("Nov 4 · 240 fps slow-mo").font(.subheadline).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Text("\(clip.shots.count) shots")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.cheddar)
            }
            .padding(14)
        }
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.08)))
        .task { thumbnail = await clip.still() }
    }
}

#Preview {
    NavigationStack { ClipLibraryView() }
}

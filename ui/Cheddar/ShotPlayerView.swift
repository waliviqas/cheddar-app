import AVFoundation
import SwiftUI

/*
This screen's only job is: play a clip and pop up each shot's speed and net square as it happens.
*/
struct ShotPlayerView: View {
    @State private var model: ShotPlayerModel
    @Environment(\.dismiss) private var dismiss
    @State private var poster: UIImage?

    init(clip: DemoClip) {
        _model = State(initialValue: ShotPlayerModel(clip: clip))
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                Color.black.ignoresSafeArea()
                if landscape {
                    video.ignoresSafeArea()
                    HStack {
                        Spacer()
                        pop.padding(.trailing, 24)
                    }
                    VStack {
                        topBar
                        Spacer()
                        shotStrip
                    }
                } else {
                    VStack(spacing: 16) {
                        topBar
                        video
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal, 8)
                        Color.clear.overlay { pop }
                        shotStrip
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: model.popped?.id)
        .animation(.easeInOut(duration: 0.2), value: model.isPlaying)
        .sensoryFeedback(.impact(weight: .heavy), trigger: model.revealed.count)
        .toolbar(.hidden, for: .navigationBar)
        .task { poster = await model.clip.still() }
        .onDisappear { model.stop() }
    }

    // The clip, with the play button on top while it's paused; tap anywhere to pause or play.
    private var video: some View {
        ZStack {
            if let poster {
                Image(uiImage: poster).resizable().scaledToFit()
            }
            PlayerLayerView(player: model.player)
            if !model.isPlaying {
                playButton
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { model.togglePlay() }
    }

    @ViewBuilder
    private var pop: some View {
        if let shot = model.popped {
            ShotPopView(shot: shot)
                .id(shot.id)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            Text(model.clip.title)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            if model.isPlaying {
                statusBadge
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // "Listening" while waiting for a shot, "Tracking" in the slow-motion moment around one.
    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(model.inSlowMotion ? Theme.goalRed : .green)
                .frame(width: 8, height: 8)
            Text(model.inSlowMotion ? "TRACKING · SLOW-MO" : "LISTENING")
                .font(.caption.weight(.bold))
                .kerning(1)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var playButton: some View {
        Button {
            model.togglePlay()
        } label: {
            Image(systemName: model.finished ? "arrow.counterclockwise" : "play.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.navy)
                .frame(width: 88, height: 88)
                .background(Theme.cheddar, in: Circle())
                .shadow(color: .black.opacity(0.4), radius: 20)
        }
        .transition(.scale.combined(with: .opacity))
    }

    // Every shot read so far, plus the hardest one.
    private var shotStrip: some View {
        HStack(spacing: 10) {
            ForEach(model.revealed) { shot in
                VStack(alignment: .leading, spacing: 2) {
                    Text("SHOT \(shot.id)")
                        .font(.caption2.weight(.bold))
                        .kerning(1)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(shot.mph.map { String(format: "%.1f mph", $0) } ?? "No read")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(shot.square?.label ?? "—")
                        .font(.caption)
                        .foregroundStyle(Theme.cheddar)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Spacer()
            if let top = model.topSpeed {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("TOP SPEED")
                        .font(.caption2.weight(.bold))
                        .kerning(1)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(String(format: "%.1f", top))
                        .font(Theme.display(34))
                        .foregroundStyle(Theme.cheddar)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.revealed.count)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// The video itself, scaled to fit the screen.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    final class LayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
    }

    func makeUIView(context: Context) -> LayerView {
        let view = LayerView()
        let layer = view.layer as! AVPlayerLayer
        layer.player = player
        layer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: LayerView, context: Context) {}
}

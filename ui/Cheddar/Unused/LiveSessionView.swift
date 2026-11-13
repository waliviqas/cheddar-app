import AVFoundation
import SwiftUI

/*
This screen's only job is: the shooting session — the camera feed full screen,
each shot's speed popping up as it happens, and ending the session to log it.
*/
struct LiveSessionView: View {
    let onFinish: (Session) -> Void
    @State private var model = LiveSessionModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Color.clear
                .overlay(alignment: .bottom) { Image("SessionLive").resizable().scaledToFill() }
                .clipped()
                .ignoresSafeArea()
            PlayerLayerView(player: model.player)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { model.togglePause() }
            NetOverlayView(corners: Demo.netCorners(at: model.elapsed), lit: model.popped?.square)
                .ignoresSafeArea()
            if model.started {
                VStack(spacing: 8) {
                    topBar
                    shotStrip
                    if let shot = model.popped {
                        ShotPopView(shot: shot)
                            .id(shot.id)
                            .transition(.scale(scale: 0.7).combined(with: .opacity))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            } else {
                startOverlay
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: model.popped?.id)
        .animation(.easeInOut(duration: 0.2), value: model.reading?.id)
        .animation(.easeInOut(duration: 0.25), value: model.started)
        .sensoryFeedback(.impact(weight: .heavy), trigger: model.revealed.count)
        .toolbar(.hidden, for: .navigationBar)
        .persistentSystemOverlays(.hidden)
        .onChange(of: model.finished) { _, finished in
            if finished { onFinish(model.session()) }
        }
        .onDisappear { model.stop() }
    }

    // Before the session: the camera is lined up on the net, waiting for the go.
    private var startOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Camera's on the net")
                    .font(Theme.display(40))
                    .foregroundStyle(.white)
                Text("Shoot whenever you're ready. Cheddar hears every shot.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                Button {
                    model.start()
                } label: {
                    Label("Start Session", systemImage: "record.circle")
                        .font(.headline)
                        .foregroundStyle(Theme.navy)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Theme.cheddar, in: Capsule())
                }
                .padding(.top, 6)
            }
            VStack {
                HStack {
                    closeButton
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(Theme.goalRed).frame(width: 10, height: 10)
                    .opacity(model.isPlaying ? 1 : 0.3)
                Text(model.elapsed.clock)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: Capsule())
            statusBadge
            Spacer()
            if let top = model.topSpeed {
                HStack(spacing: 6) {
                    Text("TOP")
                        .font(.caption2.weight(.bold))
                        .kerning(1)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(String(format: "%.1f", top))
                        .font(Theme.display(22))
                        .foregroundStyle(Theme.cheddar)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
            }
            Button {
                model.end()
            } label: {
                Text("End Session")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.goalRed, in: Capsule())
            }
        }
        .environment(\.colorScheme, .dark)
    }

    // "Listening" between shots; "Shot detected" while Cheddar reads one.
    private var statusBadge: some View {
        HStack(spacing: 8) {
            if model.wrappingUp {
                ProgressView().controlSize(.small).tint(.green)
                Text("SAVING SESSION")
                    .foregroundStyle(.green)
            } else if model.reading != nil {
                ProgressView().controlSize(.small).tint(Theme.cheddar)
                Text("SHOT DETECTED · READING")
                    .foregroundStyle(Theme.cheddar)
            } else if model.isPlaying {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("LISTENING")
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "pause.fill").foregroundStyle(.white)
                Text("PAUSED").foregroundStyle(.white)
            }
        }
        .font(.caption.weight(.bold))
        .kerning(1)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .transaction { $0.animation = nil }
    }

    // The latest shots read, newest on the right; the full list is in the session summary.
    private var shotStrip: some View {
        HStack(spacing: 6) {
            ForEach(model.revealed.suffix(8)) { shot in
                LiveChip(shot: shot)
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(height: model.revealed.isEmpty ? 0 : 36)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.revealed.count)
        .environment(\.colorScheme, .dark)
    }
}

// One shot in the live strip, small enough to sit over the sky: "3  54.9".
private struct LiveChip: View {
    let shot: Shot

    var body: some View {
        HStack(spacing: 6) {
            Text("\(shot.id)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.navy)
                .frame(width: 18, height: 18)
                .background(Theme.cheddar, in: Circle())
            Text(shot.mph.map { String(format: "%.1f", $0) } ?? "—")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// One shot in the running list: its number, speed, and square.
struct ShotChip: View {
    let shot: Shot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("SHOT \(shot.id)")
                .font(.caption2.weight(.bold))
                .kerning(1)
                .foregroundStyle(.white.opacity(0.6))
            Text(shot.mph.map { String(format: "%.1f", $0) } ?? "No read")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
            Text(shot.square?.label ?? "—")
                .font(.caption2)
                .foregroundStyle(Theme.cheddar)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// The video itself, filling the screen like a camera feed; it sits on the bottom edge so only sky gets cut.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    final class LayerView: UIView {
        let playerLayer = AVPlayerLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            clipsToBounds = true
            playerLayer.videoGravity = .resizeAspect
            layer.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) { nil }

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = VideoFit(video: Demo.videoSize, view: bounds.size).frame
            CATransaction.commit()
        }
    }

    func makeUIView(context: Context) -> LayerView {
        let view = LayerView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: LayerView, context: Context) {}
}

import AVFoundation
import Observation
import SwiftUI

/*
This screen's only job is: replay one shot — the clip slows down as the stick hits the puck,
then the speed and net square pop up.
*/
struct ShotReplayView: View {
    let shot: Shot
    @State private var model: ReplayModel
    @Environment(\.dismiss) private var dismiss

    init(shot: Shot) {
        self.shot = shot
        _model = State(initialValue: ReplayModel(clip: shot.clip.flatMap(Demo.video)))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ReplayLayerView(player: model.player)
                .ignoresSafeArea()
            HStack {
                Spacer()
                if model.revealed {
                    ShotPopView(shot: shot)
                        .padding(.trailing, 24)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            VStack {
                HStack(spacing: 10) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Text("SHOT \(shot.id) · REPLAY")
                        .font(.caption.weight(.bold))
                        .kerning(1.5)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                    if model.slow {
                        Text("SLOW-MO")
                            .font(.caption.weight(.bold))
                            .kerning(1.5)
                            .foregroundStyle(Theme.cheddar)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    Spacer()
                    if model.finished {
                        Button { model.play() } label: {
                            Label("Watch Again", systemImage: "arrow.counterclockwise")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.navy)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Theme.cheddar, in: Capsule())
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .environment(\.colorScheme, .dark)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: model.revealed)
        .animation(.easeInOut(duration: 0.2), value: model.finished)
        .onAppear { model.play() }
        .onDisappear { model.stop() }
        .persistentSystemOverlays(.hidden)
    }
}

// Plays the clip at normal speed, drops to slow motion around the hit, and says when to show the number.
@MainActor
@Observable
final class ReplayModel {
    static let slowFrom = Demo.replayShotAt - 0.5
    static let slowUntil = Demo.replayShotAt + 0.6
    static let revealAt = Demo.replayShotAt + 0.35
    static let slowRate: Float = 0.25

    let player = AVPlayer()
    private(set) var slow = false
    private(set) var revealed = false
    private(set) var finished = false
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    init(clip: URL?) {
        guard let clip else { return }
        let item = AVPlayerItem(url: clip)
        player.replaceCurrentItem(with: item)
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 60), queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time.seconds) }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.finished = true }
        }
    }

    func play() {
        finished = false
        revealed = false
        slow = false
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            MainActor.assumeIsolated { self?.player.rate = 1 }
        }
    }

    func stop() {
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
    }

    private func tick(_ seconds: Double) {
        guard !finished else { return }
        let nowSlow = seconds >= Self.slowFrom && seconds < Self.slowUntil
        if nowSlow != slow {
            slow = nowSlow
            if player.rate > 0 { player.rate = nowSlow ? Self.slowRate : 1 }
        }
        if !revealed && seconds >= Self.revealAt { revealed = true }
    }
}

// The replay video, scaled to fit the screen.
struct ReplayLayerView: UIViewRepresentable {
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

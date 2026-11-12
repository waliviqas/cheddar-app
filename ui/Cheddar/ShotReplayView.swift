import AVFoundation
import Observation
import SwiftUI

/*
This screen's only job is: replay one shot, slowing down as the stick hits the puck, with the shot's speed
and net square shown the whole time. Upright, the numbers sit under the video; sideways, beside it.
*/
struct ShotReplayView: View {
    let shot: Shot
    @State private var model: ReplayModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSize

    init(shot: Shot) {
        self.shot = shot
        _model = State(initialValue: ReplayModel(clip: shot.clip.flatMap(Demo.video)))
    }

    private var sideways: Bool { verticalSize == .compact }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if sideways {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        closeButton
                        video
                    }
                    info.frame(width: 250)
                }
                .padding(.horizontal, 12)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    closeButton
                    video
                    info
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .environment(\.colorScheme, .dark)
        .animation(.easeInOut(duration: 0.2), value: model.slow)
        .onAppear { model.play() }
        .onDisappear { model.stop() }
        .persistentSystemOverlays(.hidden)
    }

    // The clip with its labels on top: "SHOT N · REPLAY", plus SLOW-MO while it's slowed down.
    private var video: some View {
        ReplayLayerView(player: model.player)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                HStack(spacing: 8) {
                    badge("SHOT \(shot.id) · REPLAY", color: .white)
                    if model.slow {
                        badge("SLOW-MO", color: Theme.cheddar)
                    }
                }
                .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .kerning(1.5)
            .foregroundStyle(color)
            .fixedSize()
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
    }

    // The shot's numbers, always on screen: speed, where it went in the net, and a way to watch it again.
    private var info: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SHOT \(shot.id)")
                .font(.caption.weight(.bold))
                .kerning(2)
                .foregroundStyle(Theme.cheddar)
            if sideways {
                speed
                net
            } else {
                HStack {
                    speed
                    Spacer()
                    net
                }
            }
            Button { model.play() } label: {
                Label("Watch Again", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.navy)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.cheddar, in: Capsule())
            }
        }
        .padding(20)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.cheddar.opacity(0.5), lineWidth: 1.5))
    }

    private var speed: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(shot.mph.mphText)
                .font(Theme.display(64))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("MPH")
                .font(.headline.weight(.heavy))
                .kerning(2)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize()
        }
    }

    @ViewBuilder
    private var net: some View {
        if let square = shot.square {
            VStack(spacing: 6) {
                NetSquareView(square: square)
                    .frame(width: 120)
                Text(square.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.cheddar)
            }
        }
    }
}

// Plays the clip at normal speed and drops to slow motion around the hit.
@MainActor
@Observable
final class ReplayModel {
    static let slowFrom = Demo.replayShotAt - 0.5
    static let slowUntil = Demo.replayShotAt + 0.6
    static let slowRate: Float = 0.25

    let player = AVPlayer()
    private(set) var slow = false
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
    }
}

// The replay video, scaled to fit.
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

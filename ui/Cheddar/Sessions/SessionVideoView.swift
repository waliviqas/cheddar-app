import AVFoundation
import Observation
import SwiftUI
import UIKit

/*
This screen's only job is: play a whole session's video and let the player move through it like a video in the
camera roll: a strip of frames to drag through, play/pause, and the time. Each shot has a yellow marker on the
strip; hold one to see that shot's number and speed. Tap the video to hide or show the controls.
Upright, the video sits in the middle under the title. Sideways, it fills the screen top to bottom.
*/
struct SessionVideoView: View {
    let session: Session
    @State private var model: SessionPlayerModel
    @State private var controlsShown = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSize

    // startAt is where the video begins, in seconds; a shot's replay opens it where that shot starts.
    init(session: Session, url: URL, startAt: Double = 0) {
        self.session = session
        _model = State(initialValue: SessionPlayerModel(url: url, startAt: startAt))
    }

    private var title: String {
        "\(session.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) · Full session"
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .onTapGesture { controlsShown.toggle() }
            if verticalSize == .compact {
                video
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                if controlsShown {
                    VStack {
                        HStack {
                            closeButton
                            Spacer()
                        }
                        Spacer()
                        controls(compact: true)
                    }
                    .padding(8)
                }
            } else {
                video
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 20)
                if controlsShown {
                    VStack {
                        HStack(spacing: 12) {
                            closeButton
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        Spacer()
                        controls(compact: false)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .animation(.easeInOut(duration: 0.2), value: controlsShown)
        .onAppear { Task { await model.start() } }
        .onDisappear { model.stop() }
        .persistentSystemOverlays(.hidden)
    }

    private var video: some View {
        ReplayLayerView(player: model.player)
            .aspectRatio(16 / 9, contentMode: .fit)
            .contentShape(Rectangle())
            .onTapGesture { controlsShown.toggle() }
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

    // The strip of frames to drag through, with play/pause and the time. Sideways it's one thin row so it covers
    // less of the video; upright the button and times sit under the strip.
    private func controls(compact: Bool) -> some View {
        let strip = Filmstrip(images: model.thumbnails, progress: model.progress,
                              shots: session.shots, duration: model.duration) { fraction, ended in
            model.scrub(to: fraction, ended: ended)
        }
        let playButton = Button { model.togglePlay() } label: {
            Image(systemName: model.playing ? "pause.fill" : "play.fill")
                .font(.title2)
                .frame(width: 44, height: 32)
        }
        return Group {
            if compact {
                HStack(spacing: 12) {
                    playButton
                    Text(model.current.clock)
                    strip.frame(height: 36)
                    Text(model.duration.clock)
                }
            } else {
                VStack(spacing: 10) {
                    strip.frame(height: 44)
                    HStack {
                        Text(model.current.clock)
                        Spacer()
                        playButton
                        Spacer()
                        Text(model.duration.clock)
                    }
                }
            }
        }
        .monospacedDigit()
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// A row of frames from the video with a white playhead; drag anywhere on it to move through the video.
// Each shot has a yellow marker where the stick hits the puck; hold one to see that shot's number and speed.
private struct Filmstrip: View {
    let images: [UIImage]
    let progress: Double
    let shots: [Shot]
    let duration: Double
    let onScrub: (Double, Bool) -> Void

    @State private var held: Shot?   // the shot whose marker is under the finger
    @State private var scrubbing = false

    // How close to a marker a touch has to land to hold it; sliding farther than this scrubs instead.
    private static let reach: CGFloat = 14

    private var marked: [Shot] {
        duration > 0 ? shots.filter { $0.clack > 0 && $0.clack <= duration } : []
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(images.indices, id: \.self) { i in
                        Image(uiImage: images[i])
                            .resizable()
                            .scaledToFill()
                            .frame(width: w / CGFloat(images.count), height: h)
                            .clipped()
                    }
                }
                .frame(width: w, height: h, alignment: .leading)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                ForEach(marked) { shot in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Theme.cheddar)
                        .frame(width: 3, height: h + 8)
                        .offset(x: x(of: shot, in: w) - 1.5)
                }
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white)
                    .frame(width: 4, height: h + 8)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .offset(x: min(max(w * progress - 2, 0), w - 4))
                if let held {
                    // A zero-size point just above the marker (kept off the strip's ends); the tag hangs centered over it.
                    Color.clear
                        .frame(width: 0, height: 0)
                        .overlay(alignment: .bottom) { ShotTag(shot: held) }
                        .offset(x: min(max(x(of: held, in: w), 60), w - 60), y: -h / 2 - 14)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if held == nil && !scrubbing {
                            held = marker(near: drag.startLocation.x, in: w)
                            scrubbing = held == nil
                        }
                        if held != nil && abs(drag.translation.width) > Self.reach {
                            held = nil
                            scrubbing = true
                        }
                        if scrubbing { onScrub(fraction(at: drag.location.x, in: w), false) }
                    }
                    .onEnded { drag in
                        if scrubbing { onScrub(fraction(at: drag.location.x, in: w), true) }
                        held = nil
                        scrubbing = false
                    }
            )
        }
    }

    private func x(of shot: Shot, in w: CGFloat) -> CGFloat {
        w * CGFloat(shot.clack / duration)
    }

    private func fraction(at touchX: CGFloat, in w: CGFloat) -> Double {
        Double(min(max(touchX / w, 0), 1))
    }

    private func marker(near touchX: CGFloat, in w: CGFloat) -> Shot? {
        let closest = marked.min { abs(x(of: $0, in: w) - touchX) < abs(x(of: $1, in: w) - touchX) }
        guard let closest, abs(x(of: closest, in: w) - touchX) <= Self.reach else { return nil }
        return closest
    }
}

// Plays the session video, keeps track of where it is, lets the strip move it, and makes the strip's frames.
@MainActor
@Observable
final class SessionPlayerModel {
    let player: AVPlayer
    private(set) var current: Double = 0
    private(set) var duration: Double = 0
    private(set) var playing = false
    private(set) var thumbnails: [UIImage] = []

    private let asset: AVURLAsset
    private let startAt: Double
    private var scrubbing = false
    private var playAfterScrub = false
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var seekTarget: CMTime?
    private var seeking = false
    private var released = false

    var progress: Double { duration > 0 ? current / duration : 0 }

    init(url: URL, startAt: Double = 0) {
        asset = AVURLAsset(url: url)
        self.startAt = startAt
        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, !self.scrubbing else { return }
                self.current = time.seconds
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.playing = false }
        }
    }

    func start() async {
        if let length = try? await asset.load(.duration) { duration = length.seconds }
        if startAt > 0 {
            current = startAt
            _ = await player.seek(to: CMTime(seconds: startAt, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        player.play()
        playing = true
        await makeThumbnails()
    }

    func togglePlay() {
        if playing {
            player.pause()
            playing = false
        } else {
            if duration > 0, current >= duration - 0.1 {
                player.seek(to: .zero)
                current = 0
            }
            player.play()
            playing = true
        }
    }

    // Moves the video to a spot on the strip (0 = start, 1 = end); playback picks back up when the finger lifts.
    // A new seek cancels one still running, so each seek finishes before the next starts and only the latest
    // spot is kept; otherwise on a phone the picture wouldn't change until the finger stopped.
    func scrub(to fraction: Double, ended: Bool) {
        if !scrubbing {
            scrubbing = true
            playAfterScrub = playing
            player.pause()
            playing = false
        }
        current = fraction * duration
        seekTarget = CMTime(seconds: current, preferredTimescale: 600)
        released = ended
        guard !seeking else { return }
        seeking = true
        Task {
            while let target = seekTarget {
                seekTarget = nil
                _ = await player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
            }
            seeking = false
            if released {
                scrubbing = false
                if playAfterScrub {
                    player.play()
                    playing = true
                }
            }
        }
    }

    func stop() {
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
    }

    private func makeThumbnails() async {
        guard duration > 0 else { return }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 90)
        var images: [UIImage] = []
        for i in 0..<12 {
            let time = CMTime(seconds: duration * (Double(i) + 0.5) / 12, preferredTimescale: 600)
            if let frame = try? await generator.image(at: time) {
                images.append(UIImage(cgImage: frame.image))
            }
        }
        thumbnails = images
    }
}

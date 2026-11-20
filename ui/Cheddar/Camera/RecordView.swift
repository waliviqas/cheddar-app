import SwiftUI

/*
This screen's only job is: show the camera, let the player set the net's 4 corners (tap, drag, undo, then the check),
draw the net's grid on them, film the session, and show the result. A signed-in player's session goes back to the
screen that opened this one; a guest sees each shot's speed here, and anyone with no shots read sees that none were found.
*/
struct RecordView: View {
    @State private var model: RecordViewModel
    @State private var dragFrom: CGPoint?  // where the dragged corner was when the finger went down
    @Environment(\.dismiss) private var dismiss

    private static let screen = "screen"

    init(onSession: ((Session) -> Void)?) {
        _model = State(initialValue: RecordViewModel(onSession: onSession))
    }

    var body: some View {
        ZStack {
            CameraPreview(session: model.recorder.session)
                .ignoresSafeArea()
            netLayer
            controls
        }
        .overlay(alignment: .topLeading) {
            closeButton
                .padding(16)
        }
        .overlay(alignment: .top) {
            if model.phase == .tapping {
                Text(model.taps.count < 4 ? "Tap the 4 corners of the net · \(model.taps.count) of 4"
                                          : "Drag a dot to move it, then tap the check")
                    .font(.footnote)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(16)
                    .allowsHitTesting(false)
            }
        }
        .task { await model.start() }
        .onDisappear { model.stop() }
    }

    // Picks which control to show for the moment the screen is in.
    @ViewBuilder
    private var controls: some View {
        switch model.phase {
        case .tapping:
            cornerButtons
        case .ready:
            recordButton
        case .recording:
            stopButton
        case .analyzing:
            ProgressView("Clocking your shots…")
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        case .result(let speeds):
            ResultView(speeds: speeds) { model.reset() }
        }
    }

    // The net's corners over the camera picture: tap to add one, drag one to move it. Once they're set, the net's grid
    // is drawn on them. It covers the whole screen, like the picture, so a spot here lines up with the video.
    private var netLayer: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .named(Self.screen)) { spot in model.tap(spot, screen: geometry.size) }
                if model.phase != .tapping, let outline = model.outline {
                    NetGridOverlay(corners: outline)
                }
                ForEach(model.taps.indices, id: \.self) { index in
                    Circle()
                        .fill(Theme.cheddar)
                        .frame(width: 14, height: 14)
                        .frame(width: 44, height: 44)  // easier to grab than the dot itself
                        .contentShape(Rectangle())
                        .gesture(drag(index))
                        .position(model.taps[index])
                }
            }
            .coordinateSpace(.named(Self.screen))
        }
        .ignoresSafeArea()
    }

    // Moves a corner with the finger without jumping it under the finger's middle.
    private func drag(_ index: Int) -> some Gesture {
        DragGesture(coordinateSpace: .named(Self.screen))
            .onChanged { drag in
                let from = dragFrom ?? model.taps[index]
                dragFrom = from
                model.move(index, to: CGPoint(x: from.x + drag.translation.width, y: from.y + drag.translation.height))
            }
            .onEnded { _ in dragFrom = nil }
    }

    // Undo takes back the last corner; the check, once all 4 are in, sets them and brings up the record button.
    private var cornerButtons: some View {
        VStack {
            Spacer()
            if !model.cameraReady {
                cameraUnavailable
            }
            HStack(spacing: 24) {
                if !model.taps.isEmpty {
                    Button { model.undo() } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Undo")
                }
                if model.taps.count == 4 {
                    Button { model.confirmCorners() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Theme.navy)
                            .frame(width: 76, height: 76)
                            .background(Theme.cheddar, in: Circle())
                    }
                    .accessibilityLabel("Done")
                }
            }
            .padding(.bottom, 32)
        }
    }

    // The big red circle that starts filming the session.
    private var recordButton: some View {
        VStack {
            Spacer()
            if !model.cameraReady {
                cameraUnavailable
            }
            Button {
                model.record()
            } label: {
                Circle()
                    .fill(.red)
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(.white, lineWidth: 4).padding(-8))
            }
            .disabled(!model.cameraReady)
            .padding(.bottom, 32)
        }
    }

    private var cameraUnavailable: some View {
        Text("Camera unavailable — Cheddar needs a real iPhone with camera access")
            .font(.footnote)
            .padding(8)
            .background(.ultraThinMaterial, in: Capsule())
    }

    // Same close button as the shot replay.
    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    // The square that stops filming and kicks off the reading.
    private var stopButton: some View {
        VStack {
            Spacer()
            Button {
                model.stopRecording()
            } label: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.red)
                    .frame(width: 56, height: 56)
                    .overlay(Circle().stroke(.white, lineWidth: 4).padding(-16))
            }
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    RecordView { _ in }
}

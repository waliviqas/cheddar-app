import SwiftUI

/*
This screen's only job is: show the camera, let the user film a shot, and reveal the speed.
*/
struct RecordView: View {
    @State private var model = RecordViewModel()

    var body: some View {
        ZStack {
            CameraPreview(session: model.recorder.session)
                .ignoresSafeArea()
            controls
        }
        .task { await model.start() }
        .onDisappear { model.stop() }
    }

    // Picks which control to show for the moment the screen is in.
    @ViewBuilder
    private var controls: some View {
        switch model.phase {
        case .idle:
            recordButton
        case .recording:
            stopButton
        case .analyzing:
            ProgressView("Clocking your shot…")
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        case .result(let mph):
            ResultView(mph: mph) { model.reset() }
        }
    }

    // The big red circle that starts filming.
    private var recordButton: some View {
        VStack {
            Spacer()
            if !model.cameraReady {
                Text("Camera unavailable — Cheddar needs a real iPhone with camera access")
                    .font(.footnote)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
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

    // The square that stops filming and kicks off the analysis.
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
    RecordView()
}

import CoreMotion
import SwiftUI

/*
This screen's only job is: show a phone turning sideways, so the player turns theirs and sets it in place, then move on
by itself once the phone is held sideways the right way: top to the left, the way the camera films.
*/
struct TurnPhoneView: View {
    let onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var sideways = SidewaysWatch()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white.ignoresSafeArea()
            VStack(spacing: 40) {
                Spacer()
                // Stands up, pauses, turns to the left (the way the rink clips were filmed), pauses, repeats.
                PhaseAnimator([false, true]) { turned in
                    Image(systemName: "iphone")
                        .font(.system(size: 120, weight: .light))
                        .foregroundStyle(Theme.navy)
                        .rotationEffect(.degrees(turned ? -90 : 0))
                } animation: { _ in
                    .easeInOut(duration: 0.9).delay(0.6)
                }
                .frame(height: 200)
                Text("Turn your phone sideways and place it in your spot")
                    .font(Theme.display(34))
                    .foregroundStyle(Theme.navy)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.navy)
                    .frame(width: 44, height: 44)
            }
            .padding(.leading, 12)
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden()
        .onAppear { sideways.start(onContinue) }
        .onDisappear { sideways.stop() }
    }
}

// Says once when the phone is held sideways with its top to the left. The motion sensor works even with rotation lock
// on; the Simulator has none, so there it goes by the phone's turn instead.
final class SidewaysWatch {
    private let motion = CMMotionManager()
    private var turns: NSObjectProtocol?

    func start(_ onSideways: @escaping () -> Void) {
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 0.1
            motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
                guard let gravity = data?.gravity, gravity.x < -0.7 else { return }  // top of the phone pointing left
                self?.stop()
                onSideways()
            }
        } else {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            turns = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil,
                                                           queue: .main) { [weak self] _ in
                guard UIDevice.current.orientation == .landscapeLeft else { return }
                self?.stop()
                onSideways()
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        if let turns { NotificationCenter.default.removeObserver(turns) }
        turns = nil
    }
}

#Preview {
    TurnPhoneView {}
}

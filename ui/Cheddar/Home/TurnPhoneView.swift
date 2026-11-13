import SwiftUI

/*
This screen's only job is: show a phone turning sideways, so the player turns theirs before filming,
then let them tap the check to move on.
*/
struct TurnPhoneView: View {
    let onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss

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
                Text("Turn your phone sideways")
                    .font(Theme.display(34))
                    .foregroundStyle(Theme.navy)
                    .multilineTextAlignment(.center)
                Spacer()
                Button(action: onContinue) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.navy)
                        .frame(width: 76, height: 76)
                        .background(Theme.cheddar, in: Circle())
                }
                .accessibilityLabel("Continue")
                .padding(.bottom, 24)
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
    }
}

#Preview {
    TurnPhoneView {}
}

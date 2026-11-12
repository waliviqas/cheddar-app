import SwiftUI

/*
This screen's only job is: welcome the player and send them on with Let It Rip.
*/
struct LandingView: View {
    let onGetStarted: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                Image("Logo")
                    .resizable()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .shadow(color: Theme.cheddar.opacity(0.25), radius: 30)
                Text("CHEDDAR")
                    .font(Theme.display(56))
                    .foregroundStyle(.white)
                    .padding(.top, 18)
                Spacer()
                Button(action: onGetStarted) {
                    Text("Let It Rip")
                        .font(.headline)
                        .foregroundStyle(Theme.navy)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.cheddar, in: Capsule())
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
        }
    }
}

#Preview {
    LandingView {}
}

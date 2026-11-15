import SwiftUI

/*
This screen's only job is: welcome the player and send them on with Let It Rip. The logo and CHEDDAR sit exactly
where the opening animation leaves them, so the animation lands on this page.
*/
struct LandingView: View {
    var introPlaying = false   // the opening animation is still on top; the button waits for it
    let onGetStarted: () -> Void

    var body: some View {
        GeometryReader { geo in
            let logo = BrandSpot.logo(in: geo.size)
            ZStack {
                Theme.background
                Image("Logo")
                    .resizable()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .shadow(color: Theme.cheddar.opacity(0.25), radius: 30)
                    .position(logo)
                Text("CHEDDAR")
                    .font(Theme.display(56))
                    .foregroundStyle(.white)
                    .position(x: logo.x, y: logo.y + BrandSpot.nameBelowLogo)
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            Button(action: onGetStarted) {
                Text("Let It Rip")
                    .font(.headline)
                    .foregroundStyle(Theme.navy)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.cheddar, in: Capsule())
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
            .opacity(introPlaying ? 0 : 1)
            .animation(.easeOut(duration: 0.45), value: introPlaying)
        }
    }
}

#Preview {
    LandingView {}
}

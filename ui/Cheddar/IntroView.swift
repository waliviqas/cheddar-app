import SwiftUI

/*
This screen's only job is: the opening animation when the player comes back after a while. The puck flies in from
the left, CHEDDAR comes up under it, then it gets out of the way. Same logo and wordmark as the Let It Rip page.
*/
struct IntroView: View {
    let onFinish: () -> Void

    @State private var puckIn = false
    @State private var nameIn = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                Image("Logo")
                    .resizable()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .shadow(color: Theme.cheddar.opacity(puckIn ? 0.25 : 0), radius: 30)
                    .rotationEffect(.degrees(puckIn ? 0 : -12))
                    .offset(x: puckIn ? 0 : -420)
                Text("CHEDDAR")
                    .font(Theme.display(56))
                    .foregroundStyle(.white)
                    .padding(.top, 18)
                    .opacity(nameIn ? 1 : 0)
                    .offset(y: nameIn ? 0 : 12)
            }
        }
        .task {
            withAnimation(.spring(duration: 0.55, bounce: 0.35)) { puckIn = true }
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeOut(duration: 0.35)) { nameIn = true }
            try? await Task.sleep(for: .milliseconds(900))
            onFinish()
        }
    }
}

#Preview {
    IntroView {}
}

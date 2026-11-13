import AuthenticationServices
import SwiftUI

/*
This screen's only job is: let the player sign in with Apple or Google, so their sessions follow them to any phone.
Until Apple and Google are set up, either button just lets the player in without a real login.
*/
struct LoginView: View {
    let onLoggedIn: () -> Void

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
                Text("Save your progress")
                    .font(Theme.display(34))
                    .foregroundStyle(.white)
                    .padding(.top, 18)
                Text("Sign in so your sessions follow you to any phone.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                Spacer()
                // Dark to sit with the navy: Apple only allows its button in black or white; Google's is its dark style.
                VStack(spacing: 12) {
                    SignInWithAppleButton(.continue) { _ in } onCompletion: { _ in onLoggedIn() }  // TEMP: no real login yet
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
                    Button { onLoggedIn() } label: {  // TEMP: no real login yet
                        HStack(spacing: 10) {
                            GoogleMark()
                                .frame(width: 18, height: 18)
                            Text("Continue with Google")
                                .font(.system(size: 20, weight: .medium))  // same size and weight as Apple's button
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(red: 0.075, green: 0.075, blue: 0.078), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
        }
    }
}

// Stand-in for Google's "G" in this picture; the real button will use Google's official one.
private struct GoogleMark: View {
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let line = size * 0.22
            let blue = Color(red: 0.26, green: 0.52, blue: 0.96)
            ZStack {
                arc(0, 0.125, blue, line)
                arc(0.125, 0.375, Color(red: 0.20, green: 0.66, blue: 0.33), line)
                arc(0.375, 0.56, Color(red: 0.98, green: 0.74, blue: 0.02), line)
                arc(0.56, 0.875, Color(red: 0.92, green: 0.26, blue: 0.21), line)
                Rectangle()
                    .fill(blue)
                    .frame(width: size / 2, height: line)
                    .offset(x: size / 4)
            }
            .frame(width: size, height: size)
        }
    }

    private func arc(_ from: CGFloat, _ to: CGFloat, _ color: Color, _ line: CGFloat) -> some View {
        Circle()
            .inset(by: line / 2)
            .trim(from: from, to: to)
            .stroke(color, lineWidth: line)
    }
}

#Preview {
    LoginView {}
}

import AuthenticationServices
import CryptoKit
import GoogleSignIn
import Supabase
import SwiftUI

/*
This screen's only job is: let the player sign in with Apple or Google, so their sessions follow them to any phone,
or continue as a guest, which keeps everything on this phone. Apple's or Google's signed note goes to Supabase,
which makes the account. A guest can come back here from the Account tab to sign in, without the guest option.
The logo sits where the opening animation leaves it, so the animation lands here and CHEDDAR turns into
"Save your progress".
*/
struct LoginView: View {
    var introPlaying = false   // the opening animation is still on top
    var showsGuest = true
    let onLoggedIn: () -> Void
    let onGuest: () -> Void

    @State private var nonce = ""
    @State private var askingGuest = false
    @State private var problem: String?

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
                    .opacity(introPlaying ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: introPlaying)
                // Waits for CHEDDAR to be gone so the two never sit on top of each other.
                VStack(spacing: 8) {
                    Text("Save your progress")
                        .font(Theme.display(34))
                        .foregroundStyle(.white)
                    Text("Sign in so your sessions follow you to any phone.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .position(x: logo.x, y: logo.y + 75 + 18 + 38)
                .opacity(introPlaying ? 0 : 1)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: introPlaying)
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) { buttons }
    }

    // Dark to sit with the navy: Apple only allows its button in black or white; Google's is its dark style.
    private var buttons: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.continue) { request in
                nonce = Self.randomNonce()
                request.requestedScopes = [.email]
                request.nonce = Self.sha256(nonce)
            } onCompletion: { result in
                Task { await finishApple(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
            Button { Task { await signInWithGoogle() } } label: {
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
            if showsGuest {
                Button { askingGuest = true } label: {
                    Text("Continue as Guest")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .alert("Your sessions won't be saved.", isPresented: $askingGuest) {
                    Button("Cancel", role: .cancel) {}
                    Button("Continue", action: onGuest)
                }
            }
            if let problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
        .opacity(introPlaying ? 0 : 1)
        .animation(.easeOut(duration: 0.4).delay(0.2), value: introPlaying)
    }

    // Hands Apple's signed note to Supabase, which checks it was made for this app and logs the player in.
    // Backing out of Apple's sheet isn't a problem, so it says nothing.
    private func finishApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
                problem = "Apple didn't send a sign-in. Please try again."
                return
            }
            do {
                _ = try await supabase.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(provider: .apple, idToken: token, nonce: nonce))
                problem = nil
                onLoggedIn()
            } catch {
                problem = "Couldn't sign in. Check your connection and try again."
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            problem = "Couldn't sign in with Apple. Please try again."
        }
    }

    // Same as Apple: Google bakes the code's fingerprint into its note, and Supabase checks the code matches.
    private func signInWithGoogle() async {
        guard let screen = Self.topScreen() else { return }
        let code = Self.randomNonce()
        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: screen, hint: nil, additionalScopes: nil, nonce: Self.sha256(code))
        } catch {
            if (error as? GIDSignInError)?.code == .canceled { return }
            problem = "Couldn't sign in with Google. Please try again."
            return
        }
        guard let token = result.user.idToken?.tokenString else {
            problem = "Google didn't send a sign-in. Please try again."
            return
        }
        do {
            _ = try await supabase.auth.signInWithIdToken(credentials: OpenIDConnectCredentials(
                provider: .google, idToken: token, accessToken: result.user.accessToken.tokenString, nonce: code))
            problem = nil
            onLoggedIn()
        } catch {
            problem = "Couldn't sign in. Check your connection and try again."
        }
    }

    // Google's sheet slides up over whatever screen is on top, which is a sheet when a guest signs in from Account.
    private static func topScreen() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let shown = top?.presentedViewController { top = shown }
        return top
    }

    // A one-time random code. Apple bakes its fingerprint into the note and Supabase checks the code matches,
    // so a note copied from somewhere else can't be reused to sign in.
    private static func randomNonce() -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<32).map { _ in characters.randomElement(using: &generator)! })
    }

    private static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

// Google's "G", drawn in code. Swap in Google's official logo file before launch.
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
    LoginView {} onGuest: {}
}

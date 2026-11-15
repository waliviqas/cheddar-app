import SwiftUI

/*
This file's only job is: pick the first screen. Until the player signs in with Apple or Google or continues as a
guest, every time the app opens: the opening animation, then Let It Rip, then the login page once they press it.
Then "What should we call you?" if they have no name yet; then the home page. A guest can sign in later from the
Account tab and keeps the name they picked. Deleting the account goes back to Let It Rip.
Once they're in, the opening animation only plays when they come back from more than three hours away. Over Let It
Rip it lands on the same logo, so it just swaps over and only the button fades in; over the home page it fades away.
*/
struct AppFlow: View {
    @AppStorage("lastLeft") private var lastLeft = 0.0  // when the player last left the app, seconds since 1970
    @AppStorage("guest") private var guest = false      // continued as a guest: everything stays on this phone
    @Environment(\.scenePhase) private var scenePhase
    @State private var signedIn = supabase.auth.currentSession != nil
    @State private var player = PlayerName()
    @State private var intro: Bool
    @State private var leftApp = false
    @State private var pressedLetItRip = false   // since the app opened or the animation last played

    private static let awayForIntro: TimeInterval = 3 * 60 * 60

    private var loggedIn: Bool { signedIn || guest }

    // Decided before the first frame, so the page underneath never flashes before the animation.
    init() {
        let defaults = UserDefaults.standard
        let loggedIn = supabase.auth.currentSession != nil || defaults.bool(forKey: "guest")
        let away = Date().timeIntervalSince1970 - defaults.double(forKey: "lastLeft")
        _intro = State(initialValue: !loggedIn || away > Self.awayForIntro)
    }

    var body: some View {
        ZStack {
            if !loggedIn && !pressedLetItRip {
                LandingView(introPlaying: intro) { pressedLetItRip = true }
            } else if !loggedIn {
                LoginView(introPlaying: intro) {
                    signedIn = true
                    player.reload()
                } onGuest: {
                    guest = true
                    player.reload()
                }
            } else if player.name == nil {
                NameView()
            } else {
                HomeView {
                    signedIn = true
                    guest = false
                    Task { await player.keepGuestName() }
                } onSignedOut: {
                    signedIn = false
                    guest = false
                    pressedLetItRip = false
                    player.forget()
                }
            }
            if intro {
                IntroView(onFinish: finishIntro)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .environment(player)
        .onAppear { lastLeft = Date().timeIntervalSince1970 }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                lastLeft = Date().timeIntervalSince1970
                leftApp = true
            }
            // Only after really leaving the app: the Apple sign-in sheet or Face ID also blink the app inactive.
            if phase == .active, leftApp {
                leftApp = false
                arrive()
            }
        }
    }

    private func arrive() {
        let now = Date().timeIntervalSince1970
        if !loggedIn {
            pressedLetItRip = false   // the animation lands on Let It Rip again
            intro = true
        } else if now - lastLeft > Self.awayForIntro {
            intro = true
        }
        lastLeft = now
    }

    private func finishIntro() {
        if loggedIn {
            withAnimation(.easeOut(duration: 0.35)) { intro = false }
        } else {
            intro = false
        }
    }
}

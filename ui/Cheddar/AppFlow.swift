import SwiftUI

/*
This file's only job is: pick the first screen. The very first time, the Let It Rip page; after that, the login page
until the player is logged in on this phone, then the home page. Coming back after more than an hour away, the puck
animation plays over it first.
*/
struct AppFlow: View {
    @AppStorage("seenLetItRip") private var seenLetItRip = false
    @AppStorage("lastLeft") private var lastLeft = 0.0  // when the player last left the app, seconds since 1970
    @Environment(\.scenePhase) private var scenePhase
    @State private var loggedIn = supabase.auth.currentSession != nil
    @State private var intro = false

    private static let awayForIntro: TimeInterval = 60 * 60

    var body: some View {
        ZStack {
            if !seenLetItRip {
                LandingView { seenLetItRip = true }
            } else if !loggedIn {
                LoginView { loggedIn = true }
            } else {
                HomeView()
            }
            if intro {
                IntroView { withAnimation(.easeOut(duration: 0.35)) { intro = false } }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear(perform: arrive)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { arrive() }
            if phase == .background { lastLeft = Date().timeIntervalSince1970 }
        }
    }

    // The player just opened or came back to the app: play the animation if they were gone over an hour.
    private func arrive() {
        let now = Date().timeIntervalSince1970
        if seenLetItRip, now - lastLeft > Self.awayForIntro { intro = true }
        lastLeft = now
    }
}

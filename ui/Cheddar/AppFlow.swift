import SwiftUI

/*
This file's only job is: show the main page first, then the home page once the player taps Get Started.
*/
struct AppFlow: View {
    @State private var atHome = false

    var body: some View {
        if atHome {
            HomeView()
        } else {
            LandingView { atHome = true }
        }
    }
}

import SwiftUI

/*
This file's only job is: boot the app and show the first screen.
*/
@main
struct CheddarApp: App {
    var body: some Scene {
        WindowGroup {
            LandingView()
        }
    }
}

import SwiftUI

/*
This file's only job is: boot the app and show the first screen.
*/
@main
struct CheddarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppFlow()
                .preferredColorScheme(.dark)
        }
    }
}

import SwiftUI
import UIKit

/*
This file's only job is: keep the app upright, except while a shot replay is open (it turns with the phone).
The switch has to happen before the replay opens: a screen that's already up won't pick up the change.
*/
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var allowed: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.allowed
    }
}

// Called right before a replay opens.
@MainActor
func letScreenTurn() {
    allowOrientations(.allButUpsideDown)
}

// Called when the replay closes, so the app stands back up.
@MainActor
func keepUpright() {
    allowOrientations(.portrait)
}

@MainActor
private func allowOrientations(_ mask: UIInterfaceOrientationMask) {
    AppDelegate.allowed = mask
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
    var screen = scene.keyWindow?.rootViewController
    while let current = screen {
        current.setNeedsUpdateOfSupportedInterfaceOrientations()
        screen = current.presentedViewController
    }
    scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
}

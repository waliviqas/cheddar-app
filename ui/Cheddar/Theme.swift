import SwiftUI

/*
This file's only job is: hold Cheddar's colors and type so every screen looks like one app.
*/
enum Theme {
    static let navy = Color(red: 0.024, green: 0.059, blue: 0.102)
    static let navyLight = Color(red: 0.086, green: 0.212, blue: 0.353)
    static let cheddar = Color(red: 1.0, green: 0.761, blue: 0.180)
    static let ice = Color(red: 0.812, green: 0.910, blue: 1.0)
    static let goalRed = Color(red: 0.878, green: 0.188, blue: 0.247)

    static let background = RadialGradient(colors: [navyLight, navy], center: .top, startRadius: 0, endRadius: 700)

    // The sporty heavy italic used for big numbers and the wordmark.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).italic().width(.condensed)
    }
}

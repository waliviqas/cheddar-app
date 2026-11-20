/*
This class's only job is: turn the player's 4 taps on the camera screen into the net's 4 corners in the video, in the
order ShotReader needs.

The camera screen fills the phone by hiding a strip at the top and bottom of the 1920 × 1080 video, so a tap is moved
past that strip and scaled up to the video's size.
*/
enum ScreenTaps {
    private static let video = Vec2(1920, 1080)

    // Top-left, top-right, bottom-right, bottom-left, whatever order they were tapped in. No answer until all 4 are in.
    static func corners(_ taps: [Vec2], screen: Vec2) -> [Vec2]? {
        guard taps.count == 4 else { return nil }
        let spots = taps.map { pixel($0, screen: screen) }.sorted { $0.y < $1.y }
        return spots[0..<2].sorted { $0.x < $1.x } + spots[2..<4].sorted { $0.x > $1.x }
    }

    // The video pixel under a tap, with the tap and the screen's size in screen points.
    static func pixel(_ tap: Vec2, screen: Vec2) -> Vec2 {
        let scale = max(screen.x / video.x, screen.y / video.y)
        let hidden = (video * scale - screen) / 2
        return (tap + hidden) / scale
    }
}

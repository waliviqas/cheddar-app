import Foundation

/*
This class's only job is: turn the camera angle the iPhone reports into the Lens numbers CameraPose needs.

The iPhone reports how wide its camera sees, as an angle across the 1920-pixel width of the video. The zoom is how far
the lens sits from the picture, in pixels: half that width over the tangent of half the angle.
*/
public enum PhoneLens {
    private static let video = Vec2(1920, 1080)

    // No lens when the phone reports no angle.
    public static func lens(fieldOfView degrees: Double) -> Lens? {
        guard degrees > 0 else { return nil }
        return Lens(zoom: video.x / 2 / tan(degrees / 2 * .pi / 180), centerX: video.x / 2, centerY: video.y / 2)
    }
}

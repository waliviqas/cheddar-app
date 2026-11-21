/*
This class's only job is: say where a shot's slow-mo replay clip starts and ends in its session's recording, so every
dot on the net gets its own replay. A clip runs from 2.2 s before the shot to 1.3 s after, the same 3.5 s as the demo
clips, and never reaches outside the recording.
*/
public enum ShotClipper {
    private static let lead = 2.2  // the replay screen slows down this far into every clip
    private static let length = 3.5

    public static func clip(shotAt time: Double, videoLength: Double) -> (start: Double, end: Double) {
        (max(0, time - lead), min(videoLength, time - lead + length))
    }
}

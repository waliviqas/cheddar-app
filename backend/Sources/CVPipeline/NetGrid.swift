/*
This class's only job is: say which square of the 3 × 3 grid a puck went through, from where its middle crossed the net.

The opening is measured in inches on the front of the net: across from the left post (0) to the right post (72),
up from the ground (0) to the crossbar (48).
*/
public enum NetGrid {
    static let width = 72.0, height = 48.0

    // A puck that clipped the post or bar counts in the square its middle crossed, since the reader can't yet tell a
    // post-and-in from a post-and-out. A middle exactly on a grid line goes to the square closer to the middle of the net.
    public static func square(across x: Double, up z: Double) -> NetSquare {
        let column = x < width / 3 ? 0 : (x > 2 * width / 3 ? 2 : 1)
        let row = z > 2 * height / 3 ? 0 : (z < height / 3 ? 2 : 1)
        return [[.topLeft, .topMiddle, .topRight],
                [.middleLeft, .middle, .middleRight],
                [.bottomLeft, .bottomMiddle, .bottomRight]][row][column]
    }
}

// NetGrid only ever gives one of the 9 squares. Post and missed stay for the app's Shot Map until it's hooked up.
public enum NetSquare: Equatable {
    case topLeft, topMiddle, topRight
    case middleLeft, middle, middleRight
    case bottomLeft, bottomMiddle, bottomRight
    case post, missed
}

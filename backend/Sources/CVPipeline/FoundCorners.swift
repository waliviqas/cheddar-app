import CoreGraphics
import simd

/*
This file's only job is: move the player's 4 corner taps onto the corners the trained net finder found, so the snap
starts from the real corners. The model's boxes are shares of the picture measured from its bottom-left; the taps are
video pixels measured from the top-left.
*/
public enum FoundCorners {
    static let labels = ["topLeft", "topRight", "bottomRight", "bottomLeft"]  // the model's names, in the taps' order

    // The middle of a box the model found, in video pixels.
    public static func spot(of box: CGRect, in frame: Vec2) -> Vec2 {
        Vec2(Double(box.midX) * frame.x, (1 - Double(box.midY)) * frame.y)
    }

    // Each tap moved onto the nearest corner the model found with the same name, when it's within half the tallest
    // post. A tap with none that close stays where it was.
    public static func nudge(_ taps: [Vec2], toward finds: [(label: String, spot: Vec2)]) -> [Vec2] {
        let reach = max(abs(taps[3].y - taps[0].y), abs(taps[2].y - taps[1].y)) / 2
        return taps.indices.map { index in
            let tap = taps[index]
            let spots = finds.filter { $0.label == labels[index] }.map(\.spot)
            guard let nearest = spots.min(by: { simd_distance($0, tap) < simd_distance($1, tap) }),
                  simd_distance(nearest, tap) <= reach else { return tap }
            return nearest
        }
    }
}

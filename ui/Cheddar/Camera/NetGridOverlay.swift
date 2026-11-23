import SwiftUI

/*
This view's only job is: draw the net's outline in gold and its 3 × 3 grid in thin white lines over the camera picture,
joined to the 4 corners the player set. The lines follow the net's perspective, so the squares on the far side of the net
look smaller, like the real net does.
*/
struct NetGridOverlay: View {
    let corners: [CGPoint]  // top-left, top-right, bottom-right, bottom-left, in screen points

    var body: some View {
        let spot = NetPerspective(corners)
        ZStack {
            Path { path in
                for third in [1.0 / 3, 2.0 / 3] {
                    path.move(to: spot(third, 0))  // the 2 lines between the posts
                    path.addLine(to: spot(third, 1))
                    path.move(to: spot(0, third))  // the 2 lines across
                    path.addLine(to: spot(1, third))
                }
            }
            .stroke(.white.opacity(0.9), lineWidth: 1)
            Path { path in
                path.addLines([spot(0, 0), spot(1, 0), spot(1, 1), spot(0, 1)])
                path.closeSubpath()
            }
            .stroke(Theme.cheddar, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        }
    }
}

// The perspective map from the net's face (0 to 1 across from the left post, 0 to 1 down from the crossbar) to the
// screen, fixed by where its 4 corners are (Heckbert's square-to-quad map).
private struct NetPerspective {
    private let a, b, c, d, e, f, g, h: Double

    init(_ corners: [CGPoint]) {
        let (x0, y0, x1, y1) = (corners[0].x, corners[0].y, corners[1].x, corners[1].y)
        let (x2, y2, x3, y3) = (corners[2].x, corners[2].y, corners[3].x, corners[3].y)
        let dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3
        let dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3
        let den = dx1 * dy2 - dx2 * dy1
        g = (dx3 * dy2 - dx2 * dy3) / den
        h = (dx1 * dy3 - dx3 * dy1) / den
        a = x1 - x0 + g * x1
        b = x3 - x0 + h * x3
        c = x0
        d = y1 - y0 + g * y1
        e = y3 - y0 + h * y3
        f = y0
    }

    func callAsFunction(_ across: Double, _ down: Double) -> CGPoint {
        let w = g * across + h * down + 1
        return CGPoint(x: (a * across + b * down + c) / w, y: (d * across + e * down + f) / w)
    }
}

import CVPipeline
import SwiftUI

/*
This view's only job is: draw the 3 × 3 grid right on the real net in the camera feed,
and light the square the last shot went in.
*/
struct NetOverlayView: View {
    let corners: [CGPoint]       // the net's inside corners in video pixels: left top, right top, right bottom, left bottom
    let lit: NetSquare?

    var body: some View {
        GeometryReader { geo in
            let toView = VideoFit(video: Demo.videoSize, view: geo.size)
            let net = NetPlane(corners: corners.map(toView.point))
            ZStack {
                if let cell = lit?.cell {
                    net.cell(row: cell.row, column: cell.column)
                        .fill(Theme.cheddar.opacity(0.55))
                        .shadow(color: Theme.cheddar, radius: 10)
                        .transition(.opacity)
                }
                net.gridLines()
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .shadow(color: .black.opacity(0.4), radius: 1)
                net.outline()
                    .stroke(Theme.cheddar.opacity(0.9), lineWidth: 1.5)
            }
            .animation(.easeOut(duration: 0.25), value: lit)
        }
        .allowsHitTesting(false)
    }
}

// How video pixels land on screen: the video fills the width and sits on the bottom edge, so only sky gets cut.
struct VideoFit {
    let video: CGSize
    let view: CGSize

    var scale: CGFloat { max(view.width / video.width, view.height / video.height) }

    var frame: CGRect {
        let size = CGSize(width: video.width * scale, height: video.height * scale)
        return CGRect(x: (view.width - size.width) / 2, y: view.height - size.height, width: size.width, height: size.height)
    }

    func point(_ p: CGPoint) -> CGPoint {
        CGPoint(x: frame.minX + p.x * scale, y: frame.minY + p.y * scale)
    }
}

// The net opening as seen at an angle: maps (across, down) from 0–1 onto the 4 corners with perspective.
struct NetPlane {
    private let a, b, c, d, e, f, g, h: CGFloat

    init(corners q: [CGPoint]) {
        let (p0, p1, p2, p3) = (q[0], q[1], q[2], q[3])
        let dx1 = p1.x - p2.x, dx2 = p3.x - p2.x, dx3 = p0.x - p1.x + p2.x - p3.x
        let dy1 = p1.y - p2.y, dy2 = p3.y - p2.y, dy3 = p0.y - p1.y + p2.y - p3.y
        let den = dx1 * dy2 - dx2 * dy1
        g = den == 0 ? 0 : (dx3 * dy2 - dx2 * dy3) / den
        h = den == 0 ? 0 : (dx1 * dy3 - dx3 * dy1) / den
        a = p1.x - p0.x + g * p1.x
        b = p3.x - p0.x + h * p3.x
        c = p0.x
        d = p1.y - p0.y + g * p1.y
        e = p3.y - p0.y + h * p3.y
        f = p0.y
    }

    func point(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
        let w = g * u + h * v + 1
        return CGPoint(x: (a * u + b * v + c) / w, y: (d * u + e * v + f) / w)
    }

    func outline() -> Path {
        Path { p in p.addLines([point(0, 0), point(1, 0), point(1, 1), point(0, 1), point(0, 0)]) }
    }

    func gridLines() -> Path {
        Path { p in
            for i in 1..<3 {
                let t = CGFloat(i) / 3
                p.move(to: point(t, 0)); p.addLine(to: point(t, 1))
                p.move(to: point(0, t)); p.addLine(to: point(1, t))
            }
        }
    }

    func cell(row: Int, column: Int) -> Path {
        let u0 = CGFloat(column) / 3, u1 = CGFloat(column + 1) / 3
        let v0 = CGFloat(row) / 3, v1 = CGFloat(row + 1) / 3
        return Path { p in p.addLines([point(u0, v0), point(u1, v0), point(u1, v1), point(u0, v1)]); p.closeSubpath() }
    }
}

import SwiftUI

/*
This view's only job is: one crowded square's dots lifting off the net so each can be tapped (watch the shot)
or held (see its tag). The dots fly out from where they sit, spread apart around their own middle in the
same layout, on a soft dark patch, and the rest of the screen dims a little. Tap anywhere else
and they fly back.
*/
struct ShotPopOut: View {
    let net: CGRect                             // the big map, in this view's space
    let shots: [(shot: Shot, spot: CGPoint)]    // spot is 0–1 inside the square
    let cell: Int                               // row * 3 + column
    let title: (Shot) -> String
    let onTap: (Shot) -> Void
    let onClose: () -> Void

    @State private var out = false
    @State private var holding: Int?

    private static let scale: CGFloat = 2
    private static let target: CGFloat = 44
    private static let grow: CGFloat = 2.2  // how much farther apart the dots spread from their middle

    var body: some View {
        let homes = shots.map { home(of: $0.spot) }
        let spots = spread(from: homes)
        ZStack(alignment: .topLeading) {
            Color.black
                .opacity(out ? 0.35 : 0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: close)
                .animation(.easeOut(duration: 0.25), value: out)
            let area = spotlight(around: spots)
            let pad = RoundedRectangle(cornerRadius: min(28, area.height / 2), style: .continuous)
            pad
                .fill(.black.opacity(0.4))
                .frame(width: area.width, height: area.height)
                .blur(radius: 10)
                .contentShape(pad)
                .onTapGesture {}  // a near miss on a dot shouldn't send them all back
                .position(x: area.midX, y: area.midY)
                .opacity(out ? 1 : 0)
                .animation(.easeOut(duration: 0.25), value: out)
            ForEach(shots.indices, id: \.self) { i in
                let shot = shots[i].shot
                SpeedDot(mph: shot.mph, scale: out ? Self.scale : 1, lifted: out)
                    .shadow(color: .black.opacity(out ? 0.6 : 0), radius: 8, y: 4)
                    .frame(width: Self.target, height: Self.target)
                    .contentShape(Circle())
                    .modifier(HoldOrTap(holding: $holding, index: i) { onTap(shot) })
                    .position(out ? spots[i] : homes[i])
                    .animation(.spring(duration: 0.45, bounce: 0.3).delay(Double(i) * 0.03), value: out)
            }
            if let holding {
                ShotTag(shot: shots[holding].shot, title: title(shots[holding].shot))
                    .position(tagPoint(above: spots[holding], size: SpeedDot.size(for: shots[holding].shot.mph, scale: Self.scale),
                                       minX: net.minX + 40, maxX: net.maxX - 40))
                    .allowsHitTesting(false)
            }
        }
        .allowsHitTesting(out)  // once they're flying back, taps reach the map again
        .onAppear { out = true }
        .sensoryFeedback(.selection, trigger: holding) { _, new in new != nil }
    }

    private func close() {
        out = false
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            onClose()
        }
    }

    // The soft dark patch behind the lifted dots: just around them, so they stand apart from the dimmed map.
    private func spotlight(around points: [CGPoint]) -> CGRect {
        let xs = points.map(\.x), ys = points.map(\.y)
        let minX = xs.min() ?? 0, minY = ys.min() ?? 0, margin: CGFloat = 46  // edge dots sit well inside the soft edge
        return CGRect(x: minX - margin, y: minY - margin,
                      width: (xs.max() ?? 0) - minX + margin * 2, height: (ys.max() ?? 0) - minY + margin * 2)
    }

    // Where the dot sits on the net now.
    private func home(of spot: CGPoint) -> CGPoint {
        CGPoint(x: net.minX + (CGFloat(cell % 3) + spot.x) * net.width / 3,
                y: net.minY + (CGFloat(cell / 3) + spot.y) * net.height / 3)
    }

    // The dots pushed out from their own middle so the group keeps its layout, nudged apart until no two are
    // closer than a fingertip, then slid back onto the net as one piece if it hangs off an edge.
    // A lone dot doesn't move.
    private func spread(from homes: [CGPoint]) -> [CGPoint] {
        let n = CGFloat(homes.count)
        let middle = CGPoint(x: homes.map(\.x).reduce(0, +) / n, y: homes.map(\.y).reduce(0, +) / n)
        var points = homes.map {
            CGPoint(x: middle.x + ($0.x - middle.x) * Self.grow, y: middle.y + ($0.y - middle.y) * Self.grow)
        }
        pushApart(&points, within: nil)
        let room = net.insetBy(dx: Self.target / 2, dy: Self.target / 2)
        let xs = points.map(\.x), ys = points.map(\.y)
        let dx = slide(xs.min() ?? 0, xs.max() ?? 0, into: room.minX, room.maxX)
        let dy = slide(ys.min() ?? 0, ys.max() ?? 0, into: room.minY, room.maxY)
        points = points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
        pushApart(&points, within: room)  // only moves dots when the group is too big for the net
        return points
    }

    // How far to move a span so it sits inside low...high (centered if it's too wide to fit).
    private func slide(_ lo: CGFloat, _ hi: CGFloat, into low: CGFloat, _ high: CGFloat) -> CGFloat {
        if hi - lo > high - low { return (low + high - lo - hi) / 2 }
        if lo < low { return low - lo }
        if hi > high { return high - hi }
        return 0
    }

    private func pushApart(_ points: inout [CGPoint], within room: CGRect?) {
        for _ in 0..<60 {
            for a in points.indices {
                for b in points.indices where b > a {
                    var dx = points[b].x - points[a].x, dy = points[b].y - points[a].y
                    var d = (dx * dx + dy * dy).squareRoot()
                    guard d < Self.target else { continue }
                    if d < 0.5 { dx = 1; dy = CGFloat(b - a) * 0.3; d = (dx * dx + dy * dy).squareRoot() }
                    let push = (Self.target - d) / 2 / d
                    points[a].x -= dx * push; points[a].y -= dy * push
                    points[b].x += dx * push; points[b].y += dy * push
                }
            }
            if let room {
                for i in points.indices {
                    points[i].x = min(max(points[i].x, room.minX), room.maxX)
                    points[i].y = min(max(points[i].y, room.minY), room.maxY)
                }
            }
        }
    }
}

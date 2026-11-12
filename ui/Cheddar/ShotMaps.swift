import CVPipeline
import SwiftUI

/*
This file's only job is: the net map — where every puck went, one dot per shot (bigger and brighter = faster).
When it's given onTap, each dot can be tapped to watch that shot.
*/
struct NetMapView: View {
    let shots: [Shot]
    var onTap: ((Shot) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                NetGridLines()
                NetFrame()
                ForEach(Array(shots.enumerated()), id: \.offset) { index, shot in
                    if let square = shot.square, let point = spot(of: square, index: index, w: w, h: h) {
                        dot(for: shot, scale: min(1, w / 260))
                            .position(point)
                    }
                }
            }
        }
        .aspectRatio(72 / 48, contentMode: .fit)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func dot(for shot: Shot, scale: CGFloat) -> some View {
        if let onTap {
            SpeedDot(mph: shot.mph, scale: scale)
                .frame(width: 34, height: 34)
                .contentShape(Circle())
                .onTapGesture { onTap(shot) }
        } else {
            SpeedDot(mph: shot.mph, scale: scale)
        }
    }

    // Somewhere inside the square, spread out so dots in the same square don't stack.
    private func spot(of square: NetSquare, index: Int, w: CGFloat, h: CGFloat) -> CGPoint? {
        let jx = scatter(index * 2), jy = scatter(index * 2 + 1)
        if let cell = square.cell {
            let x = (CGFloat(cell.column) + 0.2 + 0.6 * jx) * w / 3
            let y = (CGFloat(cell.row) + 0.2 + 0.6 * jy) * h / 3
            return CGPoint(x: x, y: y)
        }
        if square == .post {
            return jx < 0.5 ? CGPoint(x: 0, y: h * (0.2 + 0.6 * jy)) : CGPoint(x: w, y: h * (0.2 + 0.6 * jy))
        }
        return jx < 0.5 ? CGPoint(x: -12, y: h * (0.3 + 0.6 * jy)) : CGPoint(x: w + 12, y: h * (0.3 + 0.6 * jy))
    }
}

// One shot as a dot: faster shots are bigger and brighter cheddar.
struct SpeedDot: View {
    let mph: Double?
    var scale: CGFloat = 1

    var body: some View {
        let strength = mph.map { min(max(($0 - 40) / 25, 0), 1) } ?? 0
        let size = max(5, (9 + 7 * strength) * scale)
        Circle()
            .fill(mph == nil ? Color.white.opacity(0.4) : Theme.cheddar.opacity(0.45 + 0.55 * strength))
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Theme.navy, lineWidth: 1.5 * scale))
            .shadow(color: Theme.cheddar.opacity(0.6 * strength), radius: 6)
    }
}

// A repeatable 0–1 number per index, so the scatter is the same every time.
private func scatter(_ i: Int) -> CGFloat {
    let x = sin(Double(i) * 12.9898 + 78.233) * 43758.5453
    return CGFloat(x - x.rounded(.down))
}

// A titled card holding one map, with an optional hint on the right.
struct MapCard<Content: View>: View {
    let title: String
    var hint: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption.weight(.bold))
                    .kerning(1.5)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                if let hint {
                    Label(hint, systemImage: "hand.tap.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.cheddar)
                }
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.08)))
    }
}

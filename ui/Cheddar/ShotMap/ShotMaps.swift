import CVPipeline
import SwiftUI

/*
This file's only job is: the net map — where every puck went, one dot per shot (bigger and brighter = faster).
Numbered (the session page), each dot also shows its shot number, and dots in the same square sit side by side
so none cover another. When it's given onTap, each dot can be tapped to watch that shot.
Given a callout (the Shot Map), holding a dot shows its tag. Given onSquare, tapping or holding a square
reports it, that square's dots hide while they're popped out (ShotPopOut), and the map shares where it sits.
*/
struct NetMapView: View {
    let shots: [Shot]
    var numbered = false
    var callout: ((Shot) -> String)? = nil   // the tag's title, e.g. "SHOT 3 · NOV 11"
    var popped: Int? = nil                  // row * 3 + column of the square whose dots are out
    var onSquare: ((Int) -> Void)? = nil
    var onTap: ((Shot) -> Void)? = nil

    @State private var holding: Int?
    @Environment(\.speedRange) private var range

    // Space between numbered dots in a square; also keeps their tap areas from overlapping.
    private static let gap: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let scale = min(1, w / 260)
            let tidy = numbered ? tidyLayout(w: w, h: h, scale: scale) : [:]
            let points = points(w: w, h: h, tidy: tidy)
            ZStack(alignment: .topLeading) {
                NetGridLines()
                NetFrame()
                if onSquare != nil { squareTargets(w: w, h: h) }
                ForEach(Array(shots.enumerated()), id: \.offset) { index, shot in
                    if let point = points[index] {
                        dot(for: shot, index: index, scale: scale * (tidy[index]?.fit ?? 1))
                            .opacity(popped != nil && inCell(shot, popped!) ? 0 : 1)
                            .position(point)
                    }
                }
                if let holding, let callout, let point = points[holding] {
                    ShotTag(shot: shots[holding], title: callout(shots[holding]))
                        .position(tagPoint(above: point, size: SpeedDot.size(for: shots[holding].mph, scale: scale, range: range), minX: 40, maxX: w - 40))
                        .allowsHitTesting(false)
                }
            }
        }
        .aspectRatio(72 / 48, contentMode: .fit)
        .anchorPreference(key: NetBounds.self, value: .bounds) { onSquare == nil ? nil : $0 }
        .sensoryFeedback(.selection, trigger: holding) { _, new in new != nil }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func dot(for shot: Shot, index: Int, scale: CGFloat) -> some View {
        let face = SpeedDot(mph: shot.mph, scale: scale, number: numbered ? shot.id : nil)
        if callout != nil {
            // Just the dot itself is a target, so the rest of the square is left for popping it out.
            let size = SpeedDot.size(for: shot.mph, scale: scale, range: range) + 8
            face
                .frame(width: size, height: size)
                .contentShape(Circle())
                .modifier(HoldOrTap(holding: $holding, index: index) { onTap?(shot) })
        } else if let onTap {
            face
                .frame(width: numbered ? SpeedDot.size(for: shot.mph, scale: scale, range: range) + Self.gap : 34, height: 34)
                .contentShape(Rectangle())
                .onTapGesture { onTap(shot) }
        } else {
            face
        }
    }

    // Dots in the same square sit side by side (up to 3 a row), centered in the square, and shrink together
    // only if they wouldn't fit. Shots on the post or wide of the net aren't in a square, so they're left to the scatter.
    private func tidyLayout(w: CGFloat, h: CGFloat, scale: CGFloat) -> [Int: (point: CGPoint, fit: CGFloat)] {
        let gap = Self.gap
        let cellW = w / 3, cellH = h / 3
        var byCell: [Int: [Int]] = [:]
        for (index, shot) in shots.enumerated() {
            if let cell = shot.square?.cell { byCell[cell.row * 3 + cell.column, default: []].append(index) }
        }
        var out: [Int: (point: CGPoint, fit: CGFloat)] = [:]
        for (key, indices) in byCell {
            let sizes = indices.map { SpeedDot.size(for: shots[$0].mph, scale: scale, range: range) }
            let rows = stride(from: 0, to: indices.count, by: 3).map { Array($0..<min($0 + 3, indices.count)) }
            let rowWidths = rows.map { row in row.map { sizes[$0] }.reduce(0, +) + gap * CGFloat(row.count - 1) }
            let rowHeights = rows.map { row in row.map { sizes[$0] }.max() ?? 0 }
            let totalHeight = rowHeights.reduce(0, +) + gap * CGFloat(rows.count - 1)
            let fit = min(1, (cellW - 6) / (rowWidths.max() ?? 1), (cellH - 6) / totalHeight)
            let centerX = (CGFloat(key % 3) + 0.5) * cellW, centerY = (CGFloat(key / 3) + 0.5) * cellH
            var y = centerY - totalHeight * fit / 2
            for (r, row) in rows.enumerated() {
                var x = centerX - rowWidths[r] * fit / 2
                for n in row {
                    let d = sizes[n] * fit
                    out[indices[n]] = (CGPoint(x: x + d / 2, y: y + rowHeights[r] * fit / 2), fit)
                    x += d + gap * fit
                }
                y += (rowHeights[r] + gap) * fit
            }
        }
        return out
    }

    private func points(w: CGFloat, h: CGFloat, tidy: [Int: (point: CGPoint, fit: CGFloat)]) -> [Int: CGPoint] {
        var out: [Int: CGPoint] = [:]
        for (index, shot) in shots.enumerated() {
            if let square = shot.square, let point = tidy[index]?.point ?? spot(of: square, index: index, w: w, h: h) {
                out[index] = point
            }
        }
        return out
    }

    // One invisible target per square that has shots: tap it or hold it to pop that square out.
    private func squareTargets(w: CGFloat, h: CGFloat) -> some View {
        let keys = Set(shots.compactMap { $0.square?.cell }.map { $0.row * 3 + $0.column }).sorted()
        return ForEach(keys, id: \.self) { key in
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .frame(width: w / 3, height: h / 3)
                .position(x: (CGFloat(key % 3) + 0.5) * w / 3, y: (CGFloat(key / 3) + 0.5) * h / 3)
                .onTapGesture { onSquare?(key) }
                .onLongPressGesture(minimumDuration: 0.3) { onSquare?(key) }
        }
    }

    private func inCell(_ shot: Shot, _ key: Int) -> Bool {
        shot.square?.cell.map { $0.row * 3 + $0.column == key } ?? false
    }

    // The shots in one square with where each sits inside it (0–1), matching where the map draws them.
    static func spots(of shots: [Shot], inCell key: Int) -> [(shot: Shot, spot: CGPoint)] {
        shots.enumerated().compactMap { index, shot in
            guard shot.square?.cell.map({ $0.row * 3 + $0.column == key }) == true else { return nil }
            return (shot, CGPoint(x: 0.2 + 0.6 * scatter(index * 2), y: 0.2 + 0.6 * scatter(index * 2 + 1)))
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

// One shot as a dot: the faster it was next to the player's own slowest and fastest, the bigger and brighter
// the cheddar, so a new record makes the old ones fade. With a number, it's written inside, small.
struct SpeedDot: View {
    let mph: Double?
    var scale: CGFloat = 1
    var number: Int? = nil
    var lifted = false  // popped out of its square: near full color, so slow shots don't fade into the map

    @Environment(\.speedRange) private var range

    static func size(for mph: Double?, scale: CGFloat, range: ClosedRange<Double>?) -> CGFloat {
        max(5, (9 + 7 * strength(of: mph, in: range)) * scale)
    }

    // 0 for the player's slowest shot, 1 for their fastest. Before there's any history, 40–65 mph.
    private static func strength(of mph: Double?, in range: ClosedRange<Double>?) -> CGFloat {
        guard let mph else { return 0 }
        let range = range ?? 40...65
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 1 }
        return CGFloat(min(max((mph - range.lowerBound) / span, 0), 1))
    }

    var body: some View {
        let strength = Self.strength(of: mph, in: range)
        let size = Self.size(for: mph, scale: scale, range: range)
        Circle()
            .fill(mph == nil ? Color.white.opacity(lifted ? 0.8 : 0.4)
                             : Theme.cheddar.opacity(lifted ? 0.85 + 0.15 * strength : 0.45 + 0.55 * strength))
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Theme.navy, lineWidth: 1.5 * scale))
            .overlay {
                if let number {
                    Text("\(number)")
                        .font(.system(size: size * 0.6, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.navy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(1)
                }
            }
            .shadow(color: Theme.cheddar.opacity(0.6 * strength), radius: 6)
    }
}

// The player's slowest to fastest readable shot so far; set once from the store at the top of the app.
extension EnvironmentValues {
    @Entry var speedRange: ClosedRange<Double>? = nil
}

// A repeatable 0–1 number per index, so the scatter is the same every time.
private func scatter(_ i: Int) -> CGFloat {
    let x = sin(Double(i) * 12.9898 + 78.233) * 43758.5453
    return CGFloat(x - x.rounded(.down))
}

// Where the big map sits on screen, so the popped-out dots can be drawn over everything.
struct NetBounds: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) { value = value ?? nextValue() }
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

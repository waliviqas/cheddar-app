import CVPipeline
import SwiftUI

/*
This view's only job is: the pop-up for one shot — its speed counting up, and where it went in the net.
*/
struct ShotPopView: View {
    let shot: Shot
    @State private var shown = 0.0

    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 0) {
                Text("SHOT \(shot.id)")
                    .font(.caption.weight(.bold))
                    .kerning(2)
                    .foregroundStyle(Theme.cheddar)
                if let mph = shot.mph {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        CountingNumber(value: shown)
                            .font(Theme.display(72))
                            .foregroundStyle(.white)
                        Text("MPH")
                            .font(.headline.weight(.heavy))
                            .kerning(2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .onAppear { withAnimation(.easeOut(duration: 0.8)) { shown = mph } }
                } else {
                    Text("NO READ")
                        .font(Theme.display(48))
                        .foregroundStyle(.white)
                    Text("Lost the puck on this one")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            if let square = shot.square {
                VStack(spacing: 6) {
                    NetSquareView(square: square)
                        .frame(width: 120)
                    Text(square.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.cheddar)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.cheddar.opacity(0.5), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.5), radius: 24)
        .environment(\.colorScheme, .dark)
    }
}

// A number that counts up as it animates, instead of jumping to the end.
private struct CountingNumber: View, Animatable {
    var value: Double
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(String(format: "%.1f", value)).monospacedDigit()
    }
}

// The net opening seen from the front, split 3 × 3, with the square the puck went in lit up.
struct NetSquareView: View {
    let square: NetSquare
    @State private var glow = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                NetGridLines()
                if let cell = square.cell {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.cheddar)
                        .frame(width: w / 3 - 4, height: h / 3 - 4)
                        .shadow(color: Theme.cheddar.opacity(glow ? 0.9 : 0.3), radius: glow ? 14 : 4)
                        .offset(x: w * CGFloat(cell.column) / 3 + 2, y: h * CGFloat(cell.row) / 3 + 2)
                }
                NetFrame(lit: square == .post)
            }
        }
        .aspectRatio(72 / 48, contentMode: .fit)
        .onAppear { withAnimation(.easeInOut(duration: 0.6).repeatForever()) { glow = true } }
    }
}

// The faint 3 × 3 lines inside the net.
struct NetGridLines: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Path { p in
                for i in 1..<3 {
                    p.move(to: CGPoint(x: w * CGFloat(i) / 3, y: 0))
                    p.addLine(to: CGPoint(x: w * CGFloat(i) / 3, y: h))
                    p.move(to: CGPoint(x: 0, y: h * CGFloat(i) / 3))
                    p.addLine(to: CGPoint(x: w, y: h * CGFloat(i) / 3))
                }
            }
            .stroke(.white.opacity(0.4), lineWidth: 1.5)
        }
    }
}

// The red posts and crossbar.
struct NetFrame: View {
    var lit = false

    var body: some View {
        UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10)
            .stroke(lit ? Theme.cheddar : Theme.goalRed, lineWidth: 5)
    }
}

#Preview(traits: .landscapeLeft) {
    ZStack {
        Theme.background.ignoresSafeArea()
        ShotPopView(shot: Demo.liveShots[1])
    }
}

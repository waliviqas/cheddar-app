import CVPipeline
import SwiftUI

/*
This view's only job is: the big pop-up for one shot — its speed counting up, and where it went in the net.
*/
struct ShotPopView: View {
    let shot: DemoShot
    @State private var shown = 0.0

    var body: some View {
        VStack(spacing: 6) {
            Text("SHOT \(shot.id)")
                .font(.caption.weight(.bold))
                .kerning(2)
                .foregroundStyle(Theme.cheddar)
            if let mph = shot.mph {
                CountingNumber(value: shown)
                    .font(Theme.display(96))
                    .foregroundStyle(.white)
                    .onAppear { withAnimation(.easeOut(duration: 0.8)) { shown = mph } }
                Text("MPH")
                    .font(.title3.weight(.heavy))
                    .kerning(3)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, -12)
            } else {
                Text("NO READ")
                    .font(Theme.display(56))
                    .foregroundStyle(.white)
                Text("Lost the puck on this one")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            if let square = shot.square {
                NetSquareView(square: square)
                    .frame(width: 150)
                    .padding(.top, 10)
                Text(square.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.cheddar)
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial.opacity(0.95), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.cheddar.opacity(0.5), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.5), radius: 30)
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
            let cell = square.cell
            ZStack(alignment: .topLeading) {
                Path { p in
                    for i in 1..<3 {
                        p.move(to: CGPoint(x: w * CGFloat(i) / 3, y: 0))
                        p.addLine(to: CGPoint(x: w * CGFloat(i) / 3, y: h))
                        p.move(to: CGPoint(x: 0, y: h * CGFloat(i) / 3))
                        p.addLine(to: CGPoint(x: w, y: h * CGFloat(i) / 3))
                    }
                }
                .stroke(.white.opacity(0.25), lineWidth: 1)
                if let cell {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.cheddar)
                        .frame(width: w / 3 - 4, height: h / 3 - 4)
                        .shadow(color: Theme.cheddar.opacity(glow ? 0.9 : 0.3), radius: glow ? 14 : 4)
                        .offset(x: w * CGFloat(cell.column) / 3 + 2, y: h * CGFloat(cell.row) / 3 + 2)
                }
                UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10)
                    .stroke(square == .post ? Theme.cheddar : Theme.goalRed, lineWidth: 5)
            }
        }
        .aspectRatio(72 / 48, contentMode: .fit)
        .onAppear { withAnimation(.easeInOut(duration: 0.6).repeatForever()) { glow = true } }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        ShotPopView(shot: DemoShot(id: 1, time: 0, mph: 57.2, square: .middleRight))
    }
}

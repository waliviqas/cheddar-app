import SwiftUI

/*
This view's only job is: draw Cheddar's mouse, front on: grey, big ears, a cheddar jersey, skates, and a stick he can
wind up and swing. stickAngle turns the stick around his hands; about -25 rests the blade on the ice by his right
skate, -110 is a full wind-up.
*/
struct CheeseMouse: View {
    var stickAngle: Double = -25

    private let fur = Color(red: 0.62, green: 0.64, blue: 0.69)
    private let snout = Color(red: 0.82, green: 0.83, blue: 0.86)
    private let pink = Color(red: 0.98, green: 0.62, blue: 0.70)
    private let line = Theme.navy

    var body: some View {
        ZStack {
            tail
            skates
            jersey
            stick
            arms
            ears
            head
        }
        .frame(width: 170, height: 180)
    }

    private var tail: some View {
        Path { p in
            p.move(to: CGPoint(x: 44, y: 140))
            p.addCurve(to: CGPoint(x: 14, y: 96), control1: CGPoint(x: 8, y: 146), control2: CGPoint(x: -2, y: 112))
        }
        .stroke(pink, style: StrokeStyle(lineWidth: 5, lineCap: .round))
    }

    private var skates: some View {
        ZStack {
            ForEach([54.0, 86.0], id: \.self) { x in
                RoundedRectangle(cornerRadius: 5).fill(Theme.navy)
                    .frame(width: 22, height: 13).position(x: x, y: 160)
                Capsule().fill(.white)
                    .frame(width: 26, height: 3.5).position(x: x, y: 170)
            }
        }
    }

    private var jersey: some View {
        ZStack {
            Ellipse().fill(Theme.cheddar)
            Rectangle().fill(Theme.navy).frame(height: 10).offset(y: 14)
        }
        .frame(width: 66, height: 72)
        .clipShape(Ellipse())
        .overlay(Ellipse().stroke(line, lineWidth: 2.5))
        .position(x: 70, y: 118)
    }

    // Shaft hangs down from his hands; the blade sticks out to the right at the bottom.
    private var stick: some View {
        let shaft = Color(white: 0.12)
        return ZStack(alignment: .topLeading) {
            Capsule().fill(shaft).frame(width: 5, height: 74)
            RoundedRectangle(cornerRadius: 3).fill(shaft).frame(width: 26, height: 9).offset(y: 67)
            Rectangle().fill(.white.opacity(0.9)).frame(width: 9, height: 9).offset(x: 12, y: 67)
        }
        .frame(width: 26, height: 76, alignment: .topLeading)
        .rotationEffect(.degrees(stickAngle), anchor: UnitPoint(x: 2.5 / 26, y: 0))
        .position(x: 110 - 2.5 + 13, y: 104 + 38)
    }

    private var arms: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 92, y: 98))
                p.addLine(to: CGPoint(x: 110, y: 104))
            }
            .stroke(fur, style: StrokeStyle(lineWidth: 10, lineCap: .round))
            Path { p in
                p.move(to: CGPoint(x: 48, y: 102))
                p.addQuadCurve(to: CGPoint(x: 106, y: 108), control: CGPoint(x: 70, y: 124))
            }
            .stroke(fur, style: StrokeStyle(lineWidth: 10, lineCap: .round))
            Circle().fill(fur).overlay(Circle().stroke(line, lineWidth: 2))
                .frame(width: 13, height: 13).position(x: 110, y: 105)
        }
    }

    private var ears: some View {
        ZStack {
            ForEach([38.0, 102.0], id: \.self) { x in
                Circle().fill(fur).overlay(Circle().stroke(line, lineWidth: 2.5))
                    .frame(width: 38, height: 38).position(x: x, y: 24)
                Circle().fill(pink).frame(width: 22, height: 22).position(x: x, y: 25)
            }
        }
    }

    private var head: some View {
        ZStack {
            Circle().fill(fur).overlay(Circle().stroke(line, lineWidth: 2.5))
                .frame(width: 66, height: 66).position(x: 70, y: 52)
            ForEach([59.0, 81.0], id: \.self) { x in
                Ellipse().fill(Theme.navy).frame(width: 10, height: 12).position(x: x, y: 47)
                Circle().fill(.white).frame(width: 4, height: 4).position(x: x + 2, y: 44)
            }
            Ellipse().fill(snout).frame(width: 32, height: 20).position(x: 70, y: 64)
            Circle().fill(pink).overlay(Circle().stroke(line, lineWidth: 1.5))
                .frame(width: 10, height: 10).position(x: 70, y: 58)
            Path { p in
                for dy in [-3.0, 2.0, 7.0] {
                    p.move(to: CGPoint(x: 58, y: 63 + dy / 2))
                    p.addLine(to: CGPoint(x: 38, y: 60 + dy))
                    p.move(to: CGPoint(x: 82, y: 63 + dy / 2))
                    p.addLine(to: CGPoint(x: 102, y: 60 + dy))
                }
            }
            .stroke(line.opacity(0.7), lineWidth: 1.2)
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        CheeseMouse()
    }
}

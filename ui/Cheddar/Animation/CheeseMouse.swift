import SwiftUI

/*
This view's only job is: draw Cheddar's mouse from behind, classic-cartoon style, taking a right-handed slap shot.
He's chubby: big round ears out of a navy helmet, whisker tips past his cheeks, a navy jersey with yellow trim and
CHEDDAR 00 on the back, hockey pants, skates and a long pink tail, with both gloves on the stick. MousePose says where
everything is right now; the intro moves it frame by frame. Drawn in a 360 × 380 box with his skates at y 370.
*/
struct MousePose {
    var lean = 0.0                         // degrees he tips round his skates (+ leans right)
    var squash = 1.0                       // below 1 squashes down, above 1 stretches up
    var twist = 0.0                        // -1 … 1: upper body turned left / right
    var knob = CGPoint(x: 226, y: 248)     // the top (left) glove, on the end of the stick
    var stickAngle = 56.0                  // degrees from the knob toward the blade: 0 points right, 90 straight down
    var stickLength = 136.0                // how long the shaft looks (shorter when it points away)
    var grip = 0.42                        // where the bottom (right) glove holds: 0 at the knob, 1 at the blade
    var bend = 0.0                         // shaft flex at impact
    var stickInFront = false               // raised behind him, toward the camera
    var topGlove = 0.0                     // 0 … 1: the top glove shows once it's up by his shoulder
    var smear = 0.0                        // 0 … 1: ghost sticks trailing a fast swing
    var ears = 0.0                         // degrees the ears flop
    var tail = 0.0                         // -1 … 1: tail swing

    static func blend(_ a: MousePose, _ b: MousePose, _ x: Double) -> MousePose {
        func m(_ p: Double, _ q: Double) -> Double { p + (q - p) * x }
        var out = b
        out.lean = m(a.lean, b.lean); out.squash = m(a.squash, b.squash); out.twist = m(a.twist, b.twist)
        out.knob = CGPoint(x: m(a.knob.x, b.knob.x), y: m(a.knob.y, b.knob.y))
        out.stickAngle = m(a.stickAngle, b.stickAngle); out.stickLength = m(a.stickLength, b.stickLength)
        out.grip = m(a.grip, b.grip); out.bend = m(a.bend, b.bend); out.topGlove = m(a.topGlove, b.topGlove)
        out.ears = m(a.ears, b.ears); out.tail = m(a.tail, b.tail)
        return out
    }
}

struct CheeseMouse: View {
    var pose = MousePose()

    static let size = CGSize(width: 360, height: 380)
    static let feet = CGPoint(x: 180, y: 370)

    var body: some View {
        let anchor = UnitPoint(x: Self.feet.x / Self.size.width, y: Self.feet.y / Self.size.height)
        return ZStack(alignment: .topLeading) {
            if !pose.stickInFront { stick }
            whiskers
            legs
            tail
            jersey
            lettering
            if !pose.stickInFront { rightArm }
            head
            if pose.stickInFront {
                stick
                rightArm
                topGlove
            }
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .scaleEffect(x: 1 / pose.squash.squareRoot(), y: pose.squash, anchor: anchor)
        .rotationEffect(.degrees(pose.lean), anchor: anchor)
        .compositingGroup()  // fades as one piece, so parts don't show through each other
    }
}

// MARK: - Body

private extension CheeseMouse {
    static let ink = Color(red: 0.03, green: 0.06, blue: 0.11)
    static let furLight = Color(red: 0.87, green: 0.88, blue: 0.92)
    static let fur = Color(red: 0.67, green: 0.69, blue: 0.75)
    static let furDark = Color(red: 0.49, green: 0.51, blue: 0.58)
    static let pink = Color(red: 0.97, green: 0.60, blue: 0.68)
    static let navyLight = Color(red: 0.15, green: 0.29, blue: 0.49)
    static let navyDark = Color(red: 0.06, green: 0.13, blue: 0.24)
    static let gloveNavy = Color(red: 0.07, green: 0.13, blue: 0.22)

    var headShift: CGFloat { 16 * pose.twist }
    var shoulderShift: CGFloat { 9 * pose.twist }

    // From behind you only see the whiskers' tips, poking out past his cheeks.
    var whiskers: some View {
        let s = headShift
        return Path { p in
            for (dy, tip) in [(-9.0, -12.0), (0.0, 0.0), (9.0, 13.0)] {
                p.move(to: CGPoint(x: 140 + s, y: 136 + dy))
                p.addQuadCurve(to: CGPoint(x: 64 + s, y: 134 + dy + tip), control: CGPoint(x: 100 + s, y: 130 + dy))
                p.move(to: CGPoint(x: 236 + s, y: 142 + dy))
                p.addQuadCurve(to: CGPoint(x: 312 + s, y: 140 + dy + tip), control: CGPoint(x: 276 + s, y: 136 + dy))
            }
        }
        .stroke(Self.ink, style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
    }

    var legs: some View {
        ZStack(alignment: .topLeading) {
            skate(at: 138)
            skate(at: 222)
            pants
        }
    }

    func skate(at x: Double) -> some View {
        let sock = Path(roundedRect: CGRect(x: x - 19, y: 318, width: 38, height: 26), cornerRadius: 8)
        let boot = Path(roundedRect: CGRect(x: x - 27, y: 336, width: 54, height: 27), cornerRadius: 10)
        let blade = Path(roundedRect: CGRect(x: x - 31, y: 363, width: 62, height: 6.5), cornerRadius: 3.2)
        return ZStack(alignment: .topLeading) {
            sock.fill(Self.navyLight)
            Path(CGRect(x: x - 19, y: 326, width: 38, height: 5)).fill(Theme.cheddar)
            sock.stroke(Self.ink, lineWidth: 3.5)
            boot.fill(Color(red: 0.07, green: 0.10, blue: 0.16))
            Path(CGRect(x: x - 23, y: 344, width: 46, height: 3.5)).fill(Theme.cheddar.opacity(0.9))
            boot.stroke(Self.ink, lineWidth: 3.5)
            blade.fill(Color(red: 0.86, green: 0.89, blue: 0.93))
            blade.stroke(Self.ink, lineWidth: 2)
        }
    }

    var pants: some View {
        let shape = FixedShape(path: Path { p in
            p.move(to: CGPoint(x: 108, y: 282))
            p.addLine(to: CGPoint(x: 252, y: 282))
            p.addCurve(to: CGPoint(x: 246, y: 330), control1: CGPoint(x: 262, y: 300), control2: CGPoint(x: 258, y: 326))
            p.addLine(to: CGPoint(x: 196, y: 333))
            p.addQuadCurve(to: CGPoint(x: 164, y: 333), control: CGPoint(x: 180, y: 314))
            p.addLine(to: CGPoint(x: 114, y: 330))
            p.addCurve(to: CGPoint(x: 108, y: 282), control1: CGPoint(x: 102, y: 326), control2: CGPoint(x: 98, y: 300))
            p.closeSubpath()
        })
        let shade = LinearGradient(colors: [Color(red: 0.11, green: 0.20, blue: 0.34), Color(red: 0.05, green: 0.10, blue: 0.19)],
                                   startPoint: UnitPoint(x: 0.3, y: 0.5), endPoint: UnitPoint(x: 0.7, y: 0.5))
        return ZStack(alignment: .topLeading) {
            shape.fill(shade)
            Path { p in
                p.move(to: CGPoint(x: 113, y: 292)); p.addLine(to: CGPoint(x: 117, y: 326))
                p.move(to: CGPoint(x: 247, y: 292)); p.addLine(to: CGPoint(x: 243, y: 326))
            }
            .stroke(Theme.cheddar, lineWidth: 5)
            shape.stroke(Self.ink, lineWidth: 4)
        }
    }

    var tail: some View {
        let t = pose.tail
        let curve = Path { p in
            p.move(to: CGPoint(x: 176, y: 304))
            p.addCurve(to: CGPoint(x: 112 + 16 * t, y: 356), control1: CGPoint(x: 172 + 6 * t, y: 340), control2: CGPoint(x: 144 + 12 * t, y: 358))
            p.addCurve(to: CGPoint(x: 36 + 26 * t, y: 318), control1: CGPoint(x: 70 + 20 * t, y: 354), control2: CGPoint(x: 34 + 26 * t, y: 346))
            p.addCurve(to: CGPoint(x: 58 + 30 * t, y: 272), control1: CGPoint(x: 38 + 26 * t, y: 290), control2: CGPoint(x: 48 + 30 * t, y: 272))
            p.addQuadCurve(to: CGPoint(x: 66 + 30 * t, y: 290), control: CGPoint(x: 74 + 30 * t, y: 274))
        }
        return ZStack(alignment: .topLeading) {
            curve.stroke(Self.ink, style: StrokeStyle(lineWidth: 12.5, lineCap: .round, lineJoin: .round))
            curve.stroke(Self.pink, style: StrokeStyle(lineWidth: 7.5, lineCap: .round, lineJoin: .round))
        }
    }

    static let torsoPath = Path { p in
        p.move(to: CGPoint(x: 128, y: 160))
        p.addCurve(to: CGPoint(x: 232, y: 160), control1: CGPoint(x: 150, y: 143), control2: CGPoint(x: 210, y: 143))
        p.addCurve(to: CGPoint(x: 272, y: 262), control1: CGPoint(x: 262, y: 174), control2: CGPoint(x: 278, y: 222))
        p.addCurve(to: CGPoint(x: 246, y: 296), control1: CGPoint(x: 270, y: 284), control2: CGPoint(x: 262, y: 294))
        p.addCurve(to: CGPoint(x: 114, y: 296), control1: CGPoint(x: 200, y: 304), control2: CGPoint(x: 160, y: 304))
        p.addCurve(to: CGPoint(x: 88, y: 262), control1: CGPoint(x: 98, y: 294), control2: CGPoint(x: 90, y: 284))
        p.addCurve(to: CGPoint(x: 128, y: 160), control1: CGPoint(x: 82, y: 222), control2: CGPoint(x: 98, y: 174))
        p.closeSubpath()
    }

    // The top of the jersey slides with his shoulders when he turns; the hem stays put.
    var jerseyTurn: CGAffineTransform {
        let c = -10 * pose.twist / 144
        return CGAffineTransform(a: 1, b: 0, c: c, d: 1, tx: -c * 290, ty: 0)
    }

    var jersey: some View {
        let shape = FixedShape(path: Self.torsoPath.applying(jerseyTurn))
        return ZStack(alignment: .topLeading) {
            shape.fill(LinearGradient(colors: [Self.navyLight, Self.navyDark],
                                      startPoint: UnitPoint(x: 0.25, y: 0.4), endPoint: UnitPoint(x: 0.78, y: 0.6)))
            ZStack(alignment: .topLeading) {
                Path(CGRect(x: 0, y: 262, width: 360, height: 9)).fill(Theme.cheddar)
                Path(CGRect(x: 0, y: 277, width: 360, height: 5.5)).fill(Theme.cheddar)
            }
            .clipShape(shape)
            shape.stroke(Self.ink, lineWidth: 4.5)
        }
    }

    var lettering: some View {
        ZStack(alignment: .topLeading) {
            outlined("CHEDDAR", size: 21, outline: 1.6).position(x: 180 + 7 * pose.twist, y: 196)
            outlined("00", size: 88, outline: 3.2).position(x: 180 + 9 * pose.twist, y: 244)
        }
    }

    // Jersey lettering: yellow with a dark outline all round.
    func outlined(_ text: String, size: CGFloat, outline: CGFloat) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * .pi / 4
                Text(text).font(Theme.display(size)).foregroundStyle(Self.ink)
                    .offset(x: cos(angle) * outline, y: sin(angle) * outline)
            }
            Text(text).font(Theme.display(size)).foregroundStyle(Theme.cheddar)
        }
    }

    var head: some View {
        let s = headShift
        let skull = Path(ellipseIn: CGRect(x: 120 + s, y: 56, width: 120, height: 120))
        return ZStack(alignment: .topLeading) {
            ear(center: CGPoint(x: 104 + s, y: 66), base: CGPoint(x: 134 + s, y: 90))
            ear(center: CGPoint(x: 256 + s, y: 66), base: CGPoint(x: 226 + s, y: 90))
            snout
            skull.fill(RadialGradient(colors: [Self.furLight, Self.fur, Self.furDark],
                                      center: UnitPoint(x: (150 + s) / 360, y: 70 / 380), startRadius: 4, endRadius: 130))
            skull.stroke(Self.ink, lineWidth: 4.5)
            helmet
        }
    }

    // Seen a little from his right, the tip of his nose and his cheek peek out past his head.
    var snout: some View {
        let s = headShift
        let nose = Path(ellipseIn: CGRect(x: 250 + s, y: 138, width: 17, height: 14))
        let cheek = Path(ellipseIn: CGRect(x: 214 + s, y: 122, width: 44, height: 40))
        return ZStack(alignment: .topLeading) {
            nose.fill(Self.pink)
            nose.stroke(Self.ink, lineWidth: 3.5)
            Path(ellipseIn: CGRect(x: 257 + s, y: 141, width: 5, height: 4)).fill(.white.opacity(0.85))
            cheek.fill(RadialGradient(colors: [Self.furLight, Self.fur],
                                      center: UnitPoint(x: (232 + s) / 360, y: 132 / 380), startRadius: 2, endRadius: 30))
            cheek.stroke(Self.ink, lineWidth: 4)
        }
    }

    func ear(center c: CGPoint, base: CGPoint) -> some View {
        let outer = Path(ellipseIn: CGRect(x: c.x - 46, y: c.y - 46, width: 92, height: 92))
        let inner = Path(ellipseIn: CGRect(x: c.x - 29 + (base.x - c.x) * 0.12, y: c.y - 25, width: 58, height: 58))
        return ZStack(alignment: .topLeading) {
            outer.fill(RadialGradient(colors: [Self.furLight, Self.fur],
                                      center: UnitPoint(x: (c.x - 14) / 360, y: (c.y - 16) / 380), startRadius: 2, endRadius: 64))
            inner.fill(Self.furDark.opacity(0.35))
            outer.stroke(Self.ink, lineWidth: 4.5)
        }
        .rotationEffect(.degrees(pose.ears), anchor: UnitPoint(x: base.x / 360, y: base.y / 380))
    }

    var helmet: some View {
        let s = headShift
        let shape = FixedShape(path: Path { p in
            p.move(to: CGPoint(x: 116 + s, y: 122))
            p.addCurve(to: CGPoint(x: 180 + s, y: 50), control1: CGPoint(x: 112 + s, y: 76), control2: CGPoint(x: 142 + s, y: 50))
            p.addCurve(to: CGPoint(x: 244 + s, y: 122), control1: CGPoint(x: 218 + s, y: 50), control2: CGPoint(x: 248 + s, y: 76))
            p.addCurve(to: CGPoint(x: 116 + s, y: 122), control1: CGPoint(x: 204 + s, y: 136), control2: CGPoint(x: 156 + s, y: 136))
            p.closeSubpath()
        })
        return ZStack(alignment: .topLeading) {
            shape.fill(LinearGradient(colors: [Self.navyLight, Self.navyDark],
                                      startPoint: UnitPoint(x: 0.35, y: 0.14), endPoint: UnitPoint(x: 0.66, y: 0.32)))
            Path(CGRect(x: 170 + 18 * pose.twist, y: 40, width: 20, height: 100)).fill(Theme.cheddar).clipShape(shape)
            shape.stroke(Self.ink, lineWidth: 4.5)
            Path { p in
                p.move(to: CGPoint(x: 136 + s, y: 94))
                p.addQuadCurve(to: CGPoint(x: 164 + s, y: 62), control: CGPoint(x: 140 + s, y: 70))
            }
            .stroke(.white.opacity(0.38), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        }
    }
}

// MARK: - Arms and stick

private extension CheeseMouse {
    var shaftControl: CGPoint {
        let a = pose.stickAngle * .pi / 180
        let heel = heelPoint(angle: a)
        return CGPoint(x: (pose.knob.x + heel.x) / 2 - sin(a) * pose.bend, y: (pose.knob.y + heel.y) / 2 + cos(a) * pose.bend)
    }

    func heelPoint(angle a: Double) -> CGPoint {
        CGPoint(x: pose.knob.x + cos(a) * pose.stickLength, y: pose.knob.y + sin(a) * pose.stickLength)
    }

    // The bottom glove sits on the (maybe bent) shaft.
    var bottomHand: CGPoint {
        let s = pose.grip, k = pose.knob, c = shaftControl, h = heelPoint(angle: pose.stickAngle * .pi / 180)
        return CGPoint(x: (1 - s) * (1 - s) * k.x + 2 * (1 - s) * s * c.x + s * s * h.x,
                       y: (1 - s) * (1 - s) * k.y + 2 * (1 - s) * s * c.y + s * s * h.y)
    }

    var rightArm: some View {
        let shoulder = CGPoint(x: 244 + shoulderShift, y: 174)
        let hand = bottomHand
        return arm(shoulder: shoulder, elbow: Self.elbow(from: shoulder, to: hand, length: 60), hand: hand)
    }

    // Where the elbow goes so both halves of the arm are `length` long, bent out to his right.
    static func elbow(from s: CGPoint, to h: CGPoint, length: Double) -> CGPoint {
        let dx = h.x - s.x, dy = h.y - s.y
        let dist = max((dx * dx + dy * dy).squareRoot(), 0.001)
        let mid = CGPoint(x: (s.x + h.x) / 2, y: (s.y + h.y) / 2)
        guard dist < 2 * length else { return mid }
        let rise = (length * length - dist * dist / 4).squareRoot()
        var nx = -dy / dist, ny = dx / dist
        if nx < 0 { nx = -nx; ny = -ny }
        return CGPoint(x: mid.x + nx * rise, y: mid.y + ny * rise)
    }

    func arm(shoulder: CGPoint, elbow: CGPoint, hand: CGPoint) -> some View {
        let sleeve = Path { p in p.move(to: shoulder); p.addLine(to: elbow); p.addLine(to: hand) }
        let stripe = Path { p in
            p.move(to: CGPoint(x: elbow.x + (hand.x - elbow.x) * 0.30, y: elbow.y + (hand.y - elbow.y) * 0.30))
            p.addLine(to: CGPoint(x: elbow.x + (hand.x - elbow.x) * 0.52, y: elbow.y + (hand.y - elbow.y) * 0.52))
        }
        return ZStack(alignment: .topLeading) {
            sleeve.stroke(Self.ink, style: StrokeStyle(lineWidth: 31, lineCap: .round, lineJoin: .round))
            sleeve.stroke(Self.navyDark, style: StrokeStyle(lineWidth: 24, lineCap: .round, lineJoin: .round))
            stripe.stroke(Theme.cheddar, style: StrokeStyle(lineWidth: 24, lineCap: .butt))
            glove(at: hand, toward: elbow)
        }
    }

    // A hockey glove lying along the forearm, yellow cuff toward the elbow.
    func glove(at hand: CGPoint, toward from: CGPoint) -> some View {
        let angle = atan2(hand.y - from.y, hand.x - from.x)
        let turn = CGAffineTransform(translationX: hand.x, y: hand.y).rotated(by: angle)
        let mitt = Path(roundedRect: CGRect(x: -16, y: -16, width: 34, height: 32), cornerRadius: 11).applying(turn)
        let cuff = Path(roundedRect: CGRect(x: -21, y: -17, width: 13, height: 34), cornerRadius: 5).applying(turn)
        return ZStack(alignment: .topLeading) {
            cuff.fill(Theme.cheddar)
            cuff.stroke(Self.ink, lineWidth: 3.5)
            mitt.fill(Self.gloveNavy)
            mitt.stroke(Self.ink, lineWidth: 3.5)
        }
    }

    var topGlove: some View {
        let a = pose.stickAngle * .pi / 180
        return glove(at: pose.knob, toward: CGPoint(x: pose.knob.x - cos(a) * 20, y: pose.knob.y - sin(a) * 20))
            .opacity(pose.topGlove)
    }

    var stick: some View {
        ZStack(alignment: .topLeading) {
            if pose.smear > 0 {
                ForEach(1..<4, id: \.self) { i in
                    stickShape(angle: pose.stickAngle - Double(i) * 13, ghost: true)
                        .opacity(pose.smear * [0, 0.5, 0.32, 0.17][i])
                }
            }
            stickShape(angle: pose.stickAngle, ghost: false)
        }
    }

    func stickShape(angle degrees: Double, ghost: Bool) -> some View {
        let a = degrees * .pi / 180
        let k = pose.knob
        let heel = heelPoint(angle: a)
        let control = CGPoint(x: (k.x + heel.x) / 2 - sin(a) * pose.bend, y: (k.y + heel.y) / 2 + cos(a) * pose.bend)
        let shaft = Path { p in p.move(to: k); p.addQuadCurve(to: heel, control: control) }
        let length = pose.stickLength / 136
        let turn = CGAffineTransform(translationX: heel.x, y: heel.y).rotated(by: a - 62 * .pi / 180)
        let blade = Path(roundedRect: CGRect(x: -4, y: -6, width: 48 * length, height: 12), cornerRadius: 6).applying(turn)
        let tape = Path { p in
            for x in [12.0, 24.0, 36.0] {
                p.move(to: CGPoint(x: x * length, y: -6)); p.addLine(to: CGPoint(x: x * length, y: 6))
            }
        }
        .applying(turn)
        return ZStack(alignment: .topLeading) {
            if ghost {
                shaft.stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                blade.fill(Color.white.opacity(0.8))
            } else {
                shaft.stroke(Self.ink, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                shaft.stroke(Color(red: 0.17, green: 0.17, blue: 0.19), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
                blade.fill(Color(white: 0.96))
                tape.stroke(Color(white: 0.72), lineWidth: 2)
                blade.stroke(Self.ink, lineWidth: 3)
                Path(ellipseIn: CGRect(x: k.x - 6.5, y: k.y - 6.5, width: 13, height: 13)).fill(Self.ink)
            }
        }
    }
}

// A path drawn exactly where it was made, so it can be used to fill, outline and clip.
private struct FixedShape: Shape {
    let path: Path
    func path(in rect: CGRect) -> Path { path }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        CheeseMouse()
    }
}

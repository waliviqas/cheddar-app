import SwiftUI

/*
This file's only job is: draw the logo's cheese puck from any angle, so the intro's camera can fly round it. Every size,
spot and hole was measured off the logo picture (1024 px), so from the logo's own angle it matches the picture exactly.
It draws in the picture's own pixels, then scales to the size asked for.
*/
struct LogoPuck {
    var center: CGPoint                      // middle of the top face, on screen
    var radius: CGFloat                      // top face radius, on screen
    var elevation = LogoPuck.logoElevation   // radians the camera sits above the face
    var roll = LogoPuck.logoRoll             // radians the puck is tipped on screen
    var spin = 0.0                           // radians the camera has gone round it: 0 is the logo's view, π/2 from behind
    var lines = 0.0                          // 0 … 1: how far the logo's speed lines have grown out the back

    static let logoElevation = asin(100 / 270.5)
    static let logoRoll = -10 * Double.pi / 180
    static let logoFaceCenter = CGPoint(x: 503.6 / 1024, y: 408.7 / 1024)  // as a share of the logo's size
    static let logoFaceRadius = 270.5 / 1024                                 // as a share of the logo's size

    func draw(in context: GraphicsContext) {
        guard radius > 0.5 else { return }
        var ctx = context
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: .radians(roll))
        ctx.scaleBy(x: radius / Self.r, y: radius / Self.r)

        let up = sin(elevation), side = cos(elevation)
        let r = Self.r, b = r * up, drop = Self.thickness * side
        if lines > 0 { drawLines(ctx) }

        let hull = Self.silhouette(r: r, b: b, drop: drop)
        ctx.fill(hull, with: .linearGradient(Self.bandColors, startPoint: CGPoint(x: -r, y: 0), endPoint: CGPoint(x: r, y: 0)))
        var band = ctx
        band.clip(to: hull)
        drawHatch(band, b: b, side: side)
        drawHoles(band, b: b, side: side)

        let face = Path(ellipseIn: CGRect(x: -r, y: -b, width: 2 * r, height: 2 * b))
        ctx.fill(face, with: .linearGradient(Self.faceColors, startPoint: CGPoint(x: 0, y: -b), endPoint: CGPoint(x: 0, y: b)))
        var top = ctx
        top.clip(to: face)
        drawSpots(top, up: up)
        top.stroke(Path(ellipseIn: CGRect(x: -r * 0.81, y: -b * 0.77 - 2, width: 2 * r * 0.81, height: 2 * b * 0.77)),
                   with: .color(Self.ring), lineWidth: 6)

        ctx.stroke(hull, with: .color(Self.ink), style: StrokeStyle(lineWidth: Self.outline, lineJoin: .round))
        ctx.stroke(face, with: .color(Self.ink), lineWidth: Self.outline)
    }

    // The outside edge: the top half of the face, straight down both sides, and the bottom half of the underside.
    private static func silhouette(r: Double, b: Double, drop: Double) -> Path {
        Path { p in
            let n = 40
            p.move(to: CGPoint(x: -r, y: 0))
            for i in 1...n {
                let a = Double.pi * (1 + Double(i) / Double(n))
                p.addLine(to: CGPoint(x: r * cos(a), y: b * sin(a)))
            }
            p.addLine(to: CGPoint(x: r, y: drop))
            for i in 1...n {
                let a = Double.pi * Double(i) / Double(n)
                p.addLine(to: CGPoint(x: r * cos(a), y: drop + b * sin(a)))
            }
            p.closeSubpath()
        }
    }

    // The crisscross on the rind, wrapped round the side so it slides as the camera circles.
    private func drawHatch(_ ctx: GraphicsContext, b: Double, side: Double) {
        let r = Self.r, depth = Self.thickness
        let gap = 30.8, slope = 1.076, phase = 24.0
        let low = r * (-Double.pi / 2 - spin) - depth / slope, high = r * (Double.pi / 2 - spin) + depth / slope
        var path = Path()
        for lean in [1.0, -1.0] {
            let first = Int(((low - phase) / gap).rounded(.down)), last = Int(((high - phase) / gap).rounded(.up))
            guard first <= last else { continue }
            for k in first...last {
                var drawing = false
                for j in 0...12 {
                    let z = depth * Double(j) / 12
                    let angle = (phase + Double(k) * gap + lean * z / slope) / r + spin
                    guard cos(angle) > 0 else { drawing = false; continue }
                    let point = CGPoint(x: r * sin(angle), y: b * cos(angle) + z * side)
                    if drawing { path.addLine(to: point) } else { path.move(to: point); drawing = true }
                }
            }
        }
        ctx.stroke(path, with: .color(Self.hatch), lineWidth: 2.6)
    }

    // Holes in the rind. One that's going round the edge gets squashed flat against it, like the real thing.
    private func drawHoles(_ ctx: GraphicsContext, b: Double, side: Double) {
        let r = Self.r
        for hole in Self.holes {
            guard cos(hole.angle + spin) > -0.2 else { continue }
            var path = Path()
            for i in 0..<24 {
                let t = Double(i) / 24 * 2 * .pi
                var angle = hole.angle + hole.halfAngle * cos(t) + spin
                angle = atan2(sin(angle), cos(angle))
                if cos(angle) < 0 { angle = angle > 0 ? .pi / 2 : -.pi / 2 }
                let z = hole.depth + hole.halfDepth * sin(t)
                let point = CGPoint(x: r * sin(angle), y: b * cos(angle) + z * side)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            ctx.fill(path, with: .color(Self.holeColor))
        }
    }

    // Spots on the top face, turning with the camera.
    private func drawSpots(_ ctx: GraphicsContext, up: Double) {
        var path = Path()
        for spot in Self.spots {
            for i in 0..<20 {
                let t = Double(i) / 20 * 2 * .pi
                let p = spot.p + spot.rp * cos(t), q = spot.q + spot.rq * sin(t)
                let point = CGPoint(x: p * cos(spin) + q * sin(spin), y: (-p * sin(spin) + q * cos(spin)) * up)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
        }
        ctx.fill(path, with: .color(Self.spotColor))
    }

    // The logo's three speed lines, growing leftward out of the back of the puck.
    private func drawLines(_ ctx: GraphicsContext) {
        for line in Self.speedLines {
            let grow = min(max((lines - line.delay) / (1 - line.delay), 0), 1)
            guard grow > 0 else { continue }
            var path = Path()
            path.move(to: CGPoint(x: line.right, y: line.y))
            path.addLine(to: CGPoint(x: line.right + (line.left - line.right) * grow, y: line.y))
            ctx.stroke(path, with: .color(line.color), style: StrokeStyle(lineWidth: line.width, lineCap: .round))
        }
    }

    // Measured off the logo picture, in its pixels, with the puck's 10° tip taken out.
    private static let r = 270.5
    private static let thickness = 172.8
    private static let outline = 13.5

    // Top face spots: where they sit on the face (p across, q toward the camera) and how big.
    private static let spots: [(p: Double, q: Double, rp: Double, rq: Double)] = [
        (122.9, -108.1, 23.8, 20.8), (-2.0, -162.2, 17.7, 15.7), (-92.1, -67.5, 41.6, 39.8),
        (77.9, 67.9, 51.9, 48.1), (-147.0, 67.8, 20.0, 18.4),
    ]

    // Rind holes: how far round (0 faces the logo's camera), how far down from the top edge, and how big.
    private static let holes: [(angle: Double, depth: Double, halfAngle: Double, halfDepth: Double)] = [
        (-42.29 * .pi / 180, 60.27, 0.1095, 32.29),
        (5.97 * .pi / 180, 97.52, 0.1108, 40.68),
        (-16.55 * .pi / 180, 133.57, 0.0528, 19.37),
        (49.62 * .pi / 180, 60.30, 0.0970, 24.75),
        // Round the back, which only shows while the camera's behind it.
        (-112 * .pi / 180, 105, 0.10, 32),
        (-150 * .pi / 180, 55, 0.08, 24),
        (-128 * .pi / 180, 140, 0.05, 17),
        (-172 * .pi / 180, 115, 0.09, 30),
        (-96 * .pi / 180, 40, 0.05, 16),
    ]

    private static let speedLines: [(y: Double, right: Double, left: Double, width: Double, color: Color, delay: Double)] = [
        (80.1, -306.6, -510.7, 35.3, Color(red: 0.69, green: 0.79, blue: 0.88), 0),
        (-15.0, -301.9, -492.0, 23.4, Color(red: 0.44, green: 0.52, blue: 0.61), 0.12),
        (175.0, -296.8, -461.9, 23.2, Color(red: 0.43, green: 0.52, blue: 0.61), 0.2),
    ]

    private static let ink = Color(red: 0.03, green: 0.07, blue: 0.12)
    private static let ring = Color(red: 1.0, green: 0.88, blue: 0.45).opacity(0.85)
    private static let spotColor = Color(red: 0.90, green: 0.54, blue: 0.0)
    private static let holeColor = Color(red: 0.48, green: 0.24, blue: 0.0)
    private static let hatch = Color(red: 0.66, green: 0.36, blue: 0.02).opacity(0.75)
    private static let faceColors = Gradient(stops: [
        .init(color: Color(red: 1.0, green: 0.86, blue: 0.34), location: 0),
        .init(color: Color(red: 1.0, green: 0.82, blue: 0.27), location: 0.3),
        .init(color: Color(red: 1.0, green: 0.78, blue: 0.21), location: 0.5),
        .init(color: Color(red: 1.0, green: 0.77, blue: 0.20), location: 1),
    ])
    private static let bandColors = Gradient(stops: [
        .init(color: Color(red: 0.70, green: 0.38, blue: 0.02), location: 0),
        .init(color: Color(red: 0.82, green: 0.48, blue: 0.03), location: 0.12),
        .init(color: Color(red: 0.93, green: 0.60, blue: 0.07), location: 0.40),
        .init(color: Color(red: 0.91, green: 0.57, blue: 0.06), location: 0.55),
        .init(color: Color(red: 0.77, green: 0.44, blue: 0.03), location: 0.80),
        .init(color: Color(red: 0.66, green: 0.35, blue: 0.01), location: 1),
    ])
}

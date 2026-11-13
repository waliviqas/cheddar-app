import SwiftUI
import simd

/*
This screen's only job is: the opening animation, shot like an action movie. The camera is already pushing in from
behind the mouse as he winds up a slap shot and crushes it. It rushes after the puck and catches up until the puck fills
the screen, circles round to its side, and then the logo's speed lines grow out the back as it settles into the Cheddar
logo. Everything comes from the time since it started, so the camera, the mouse and the puck stay in step.
*/
struct IntroView: View {
    let onFinish: () -> Void

    @State private var start = Date()
    @State private var hit = 0
    @State private var landed = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                IntroFrame(shot: IntroShot(t: Self.clock(timeline.date, start), size: geo.size))
            }
        }
        .ignoresSafeArea()
        .sensoryFeedback(.impact(weight: .heavy), trigger: hit)
        .sensoryFeedback(.impact(weight: .medium), trigger: landed)
        .task { await cue() }
    }

    // A thud on the hit and on the landing, then out of the way.
    private func cue() async {
        do {
            try await wait(until: IntroShot.hitTime)
            hit += 1
            try await wait(until: IntroShot.landTime)
            landed += 1
            try await wait(until: IntroShot.length)
            #if DEBUG
            if Self.pinned > 0 { return }
            #endif
            onFinish()
        } catch {}
    }

    private func wait(until second: Double) async throws {
        let left = second - Date().timeIntervalSince(start)
        if left > 0 { try await Task.sleep(for: .seconds(left)) }
    }

    private static func clock(_ now: Date, _ start: Date) -> Double {
        #if DEBUG
        if pinned > 0 { return pinned }
        #endif
        return now.timeIntervalSince(start)
    }

    static var showsPuckLate: Bool {
        #if DEBUG
        return noLogo
        #else
        return false
        #endif
    }

    #if DEBUG
    // For lining shots up: launch with -introAt 2.2 to hold the intro at that second, -introNoLogo YES to leave the logo out.
    static let pinned = UserDefaults.standard.double(forKey: "introAt")
    static let noLogo = UserDefaults.standard.bool(forKey: "introNoLogo")
    #endif
}

private struct IntroFrame: View {
    let shot: IntroShot

    var body: some View {
        ZStack {
            Theme.background
            scene.opacity(shot.fade)   // the navy is there from the first frame; only what's on it fades in
        }
    }

    private var scene: some View {
        ZStack {
            if let shadow = shot.mouseShadow {
                Ellipse()
                    .fill(EllipticalGradient(colors: [Color.black.opacity(0.5), .clear], center: .center,
                                             startRadiusFraction: 0, endRadiusFraction: 0.5))
                    .frame(width: shadow.size.width, height: shadow.size.height)
                    .position(shadow.center)
                    .opacity(shadow.opacity)
            }
            Canvas { context, _ in shot.puck?.draw(in: context) }
            if let mouse = shot.mouse {
                CheeseMouse(pose: mouse.pose)
                    .scaleEffect(mouse.scale)
                    .position(mouse.center)
                    .opacity(mouse.opacity)
            }
            Image("Logo")
                .resizable()
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                .shadow(color: Theme.cheddar.opacity(0.25 * shot.logoOpacity), radius: 30)
                .opacity(shot.logoOpacity)
                .position(shot.logo)
            Text("CHEDDAR")
                .font(Theme.display(56))
                .foregroundStyle(.white)
                .opacity(shot.nameOpacity)
                .position(x: shot.logo.x, y: shot.logo.y + 123 + 12 * (1 - shot.nameOpacity))
        }
    }
}

// Everything on screen at one moment of the intro.
private struct IntroShot {
    static let hitTime = 0.70     // blade meets puck
    static let chaseEnd = 1.30    // camera has caught the puck
    static let orbitEnd = 1.80    // camera is round at its side
    static let settleEnd = 2.35   // puck has settled into the logo spot
    static let landTime = 2.30
    static let length = 3.5

    var fade = 1.0
    var puck: LogoPuck?
    var mouse: MousePlacement?
    var mouseShadow: ShadowPlacement?
    var logo = CGPoint.zero
    var logoOpacity = 0.0
    var nameOpacity = 0.0

    init(t: Double, size: CGSize) {
        let w = Double(size.width), h = Double(size.height)
        let focal = (h / 2) / tan(World.fieldOfView / 2)
        logo = CGPoint(x: w / 2, y: h / 2 - 37)
        fade = Ease.out(span(t, 0, 0.14))
        let face = CGPoint(x: logo.x - 75 + LogoPuck.logoFaceCenter.x * 150, y: logo.y - 75 + LogoPuck.logoFaceCenter.y * 150)
        let landed = LogoPuck.logoFaceRadius * 150
        let close = focal * World.puckRadius / World.chase   // the puck's size once the camera's caught it
        let middle = CGPoint(x: w / 2, y: h / 2)

        if t < Self.chaseEnd {
            let cam = World.camera(at: t, focal: focal, width: w, height: h)
            placePuck(cam: cam, t: t, focal: focal)
            placeMouse(cam: cam, t: t, focal: focal)
        } else if t < Self.orbitEnd {
            let v = Ease.inOut(span(t, Self.chaseEnd, Self.orbitEnd))
            puck = LogoPuck(center: middle, radius: close * (1 + 0.05 * sin(.pi * v)), elevation: LogoPuck.logoElevation,
                            roll: LogoPuck.logoRoll * v, spin: .pi / 2 * (1 - v))
        } else if t < 2.7 || IntroView.showsPuckLate {
            let v = Ease.inOut(span(t, Self.orbitEnd, Self.settleEnd))
            puck = LogoPuck(center: blend(middle, face, v), radius: close + (landed - close) * v,
                            lines: Ease.out(span(t, Self.orbitEnd, Self.settleEnd - 0.08)))
        }
        logoOpacity = Ease.out(span(t, 2.28, 2.52))
        nameOpacity = Ease.out(span(t, 2.45, 2.80))
        #if DEBUG
        if IntroView.noLogo { logoOpacity = 0; nameOpacity = 0 }
        #endif
    }

    private mutating func placePuck(cam: Cam, t: Double, focal: Double) {
        let top = World.puckTop(at: t)
        guard let spot = cam.project(top) else { return }
        let toCamera = cam.position - top
        puck = LogoPuck(center: spot.point, radius: focal * World.puckRadius / spot.depth,
                        elevation: asin(toCamera.y / simd_length(toCamera)), roll: 0, spin: atan2(-toCamera.z, toCamera.x))
    }

    private mutating func placeMouse(cam: Cam, t: Double, focal: Double) {
        guard let spot = cam.project(World.mouseCenter) else { return }
        let opacity = min(max((spot.depth - 1.1) / 0.6, 0), 1)   // he's gone by the time the camera flies past
        guard opacity > 0 else { return }
        mouse = MousePlacement(pose: MouseTrack.pose(at: t), center: spot.point,
                               scale: focal / spot.depth / World.pixelsPerUnit, opacity: opacity)
        let feet = World.mouseFeet
        if let middle = cam.project(feet),
           let left = cam.project(feet - SIMD3(0.42, 0, 0)), let right = cam.project(feet + SIMD3(0.42, 0, 0)),
           let near = cam.project(feet - SIMD3(0, 0, 0.12)), let far = cam.project(feet + SIMD3(0, 0, 0.12)) {
            mouseShadow = ShadowPlacement(center: middle.point,
                                          size: CGSize(width: right.point.x - left.point.x, height: max(near.point.y - far.point.y, 1)),
                                          opacity: opacity)
        }
    }
}

private struct MousePlacement {
    var pose: MousePose
    var center: CGPoint
    var scale: CGFloat
    var opacity: Double
}

private struct ShadowPlacement {
    var center: CGPoint
    var size: CGSize
    var opacity: Double
}

// The little world the first half happens in: y up, the mouse standing at the middle, shooting toward +z.
private enum World {
    static let fieldOfView = 40 * Double.pi / 180
    static let pixelsPerUnit = 340.0                                   // the mouse drawing's pixels per world unit
    static let mouseCenter = SIMD3<Double>(0, (370 - 190) / 340, 0)    // middle of his 360 × 380 drawing
    static let mouseFeet = SIMD3<Double>(0.03, 0, 0)
    static let puckRadius = 0.065
    static let puckRest = SIMD3<Double>(0.43, 0.065 * 172.8 / 270.5, 0) // top of the puck, sitting by his blade
    static let chase = 0.78                                            // how close the camera gets behind the puck
    static let flight = SIMD3<Double>(0, 0.28, 6.0)                    // the puck's speed, units per second

    static func puckTop(at t: Double) -> SIMD3<Double> {
        puckRest + flight * max(0, t - IntroShot.hitTime)
    }

    // Already pushing in behind him; after the hit it whips past his right shoulder and chases the puck down.
    static func camera(at t: Double, focal: Double, width: Double, height: Double) -> Cam {
        let startAt = SIMD3<Double>(0.06, 0.66, -3.6), startLook = SIMD3<Double>(0.10, 0.62, 1.0)
        let hitAt = SIMD3<Double>(0.12, 0.64, -2.95), hitLook = SIMD3<Double>(0.14, 0.58, 1.0)
        let lift = 70.0   // frames him lower on screen at the start
        if t <= IntroShot.hitTime {
            let x = span(t, 0, IntroShot.hitTime)
            return Cam(position: blend(startAt, hitAt, x), look: blend(startLook, hitLook, x), focal: focal,
                       center: CGPoint(x: width / 2, y: height / 2 + lift))
        }
        let u = Ease.inOut(span(t, IntroShot.hitTime, IntroShot.chaseEnd))
        let top = puckTop(at: t)
        let behind = top + SIMD3(0, chase * sin(LogoPuck.logoElevation), -chase * cos(LogoPuck.logoElevation))
        let swing = SIMD3<Double>(0.42, 0.16, 0) * sin(.pi * u)
        return Cam(position: blend(hitAt, behind, u) + swing, look: blend(hitLook, top, Ease.smooth(span(u, 0, 0.55))),
                   focal: focal, center: CGPoint(x: width / 2, y: height / 2 + lift * (1 - Ease.smooth(span(u, 0, 0.85)))))
    }
}

private struct Cam {
    var position: SIMD3<Double>
    var look: SIMD3<Double>
    var focal: Double
    var center: CGPoint

    func project(_ p: SIMD3<Double>) -> (point: CGPoint, depth: Double)? {
        let forward = simd_normalize(look - position)
        let right = simd_normalize(simd_cross(SIMD3<Double>(0, 1, 0), forward))
        let up = simd_cross(forward, right)
        let d = p - position
        let depth = simd_dot(d, forward)
        guard depth > 0.05 else { return nil }
        return (CGPoint(x: center.x + focal * simd_dot(d, right) / depth, y: center.y - focal * simd_dot(d, up) / depth), depth)
    }
}

// The slap shot, pose by pose.
private enum MouseTrack {
    static let address = MousePose()
    static let top: MousePose = {
        var p = MousePose()
        p.lean = 3; p.squash = 0.96; p.twist = 1
        p.knob = CGPoint(x: 258, y: 162); p.stickAngle = -64; p.stickLength = 196; p.grip = 0.36
        p.topGlove = 1; p.ears = -7; p.tail = 0.8
        return p
    }()
    static let peak: MousePose = {
        var p = top
        p.knob = CGPoint(x: 260, y: 158); p.stickAngle = -68; p.ears = -8
        return p
    }()
    static let impact: MousePose = {
        var p = MousePose()
        p.lean = -2; p.squash = 0.93; p.twist = -0.5
        p.knob = CGPoint(x: 232, y: 255); p.stickAngle = 58; p.stickLength = 128; p.bend = 9
        p.ears = 9; p.tail = -1
        return p
    }()
    static let through: MousePose = {
        var p = MousePose()
        p.lean = -4; p.squash = 1.02; p.twist = -0.9
        p.knob = CGPoint(x: 216, y: 232); p.stickAngle = -10; p.stickLength = 118
        p.ears = 4; p.tail = -0.6
        return p
    }()
    static let finish: MousePose = {
        var p = MousePose()
        p.lean = -5; p.squash = 1.05; p.twist = -1
        p.knob = CGPoint(x: 198, y: 212); p.stickAngle = -82; p.stickLength = 150
        return p
    }()

    static func pose(at t: Double) -> MousePose {
        var p: MousePose
        switch t {
        case ..<0.18: p = address
        case ..<0.50: p = MousePose.blend(address, top, Ease.out(span(t, 0.18, 0.50)))      // wind up
        case ..<0.60: p = MousePose.blend(top, peak, span(t, 0.50, 0.60))                    // hold it…
        case ..<0.70: p = MousePose.blend(peak, impact, Ease.inCubic(span(t, 0.60, 0.70)))   // …and crush it
        case ..<0.82: p = MousePose.blend(impact, through, Ease.out(span(t, 0.70, 0.82)))
        default: p = MousePose.blend(through, finish, Ease.out(span(t, 0.82, 0.98)))
        }
        if t < 0.18 { p.lean += 0.8 * sin(t * 24) }                                    // settling in
        if t >= 0.50 && t < 0.60 { p.stickAngle += 1.3 * sin((t - 0.50) * 95) }        // trembling at the top
        p.stickInFront = t >= 0.30 && t < 0.69
        if t < 0.50 { p.topGlove = Ease.out(span(t, 0.30, 0.42)) }
        p.smear = t >= 0.61 && t < 0.705 ? Ease.out(span(t, 0.61, 0.645)) : 0
        return p
    }
}

private enum Ease {
    static func out(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    static func inCubic(_ x: Double) -> Double { x * x * x }
    static func inOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
    static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }
}

private func span(_ t: Double, _ from: Double, _ to: Double) -> Double { min(max((t - from) / (to - from), 0), 1) }
private func blend(_ a: CGPoint, _ b: CGPoint, _ x: Double) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * x, y: a.y + (b.y - a.y) * x)
}
private func blend(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ x: Double) -> SIMD3<Double> { a + (b - a) * x }

#Preview {
    IntroView {}
}

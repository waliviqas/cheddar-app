import Testing
import Foundation
import CoreGraphics
import ImageIO
import simd
@testable import CVPipeline

/*
Net coordinates, in inches: x runs along the goal line from the left post to the right post,
y runs out of the goal toward the shooter, z runs up from the ice.
The opening's inside corners are top-left (0,0,48), top-right (72,0,48), bottom-right (72,0,0), bottom-left (0,0,0).
*/
@Suite("CameraPose")
struct CameraPoseTests {

    /*
    - A pretend phone 233 in in front of the goal line, 30 in left of the left post, 61.5 in off the ice, aimed at the net
    - The net's 4 inside corners are worked out by math for exactly where they'd land in its picture
    - CameraPose should find the phone within 1 inch and which way it's aimed within half a degree
    */
    @Test("finds a pretend phone from perfect corners")
    func perfectCorners() throws {
        let phone = PretendPhone(at: SIMD3(-30, 233, 61.5), aimedAt: SIMD3(60, 0, 24))

        let pose = try #require(CameraPose(corners: phone.picture(of: insideCorners), lens: phone.lens))

        #expect(simd_distance(pose.position, phone.position) <= 1)
        #expect(degrees(between: pose.forward, phone.forward) <= 0.5)
    }

    /*
    - Same pretend phone, but each corner is nudged 3 px in a different direction, like a real-life miss
    - CameraPose should still find the phone within 6 inches and its aim within 2 degrees
    */
    @Test("stays close when the corners are a few pixels off")
    func slightlyOffCorners() throws {
        let phone = PretendPhone(at: SIMD3(-30, 233, 61.5), aimedAt: SIMD3(60, 0, 24))
        let nudges = [CGPoint(x: 3, y: 0), CGPoint(x: 0, y: -3), CGPoint(x: -3, y: 0), CGPoint(x: 0, y: 3)]
        let corners = zip(phone.picture(of: insideCorners), nudges).map { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }

        let pose = try #require(CameraPose(corners: corners, lens: phone.lens))

        #expect(simd_distance(pose.position, phone.position) <= 6)
        #expect(degrees(between: pose.forward, phone.forward) <= 2)
    }

    /*
    - Wali's 3 newest rink clips, filmed on an iPhone 14 Plus at 1x, where Wali measured the setup with a tape measure
    - The corners come from NetCornerFinder (taps = Wali's clicks, plus SAM 3's saved colored-in frame), like the real app
    - The lens zoom is the typical iPhone 1x value, not measured for this phone, so the limits are looser:
      the camera should come out within 6 in of 61.5 in off the ice, and its tripod within 12 in of 233 in
      from the middle of the goal line, measured along the ice (that's what Wali taped: middle of tripod to middle of goal line)
    */
    @Test("matches Wali's tape-measured setup in the newest rink clips")
    func realClips() throws {
        let lens = LensInfo(width: 1920, height: 1080, centerX: 960, centerY: 540, zoom: iPhone1xZoom)

        for clip in try loadAnswers("net-outline.json") {
            let name = clip.clip.replacingOccurrences(of: "1x-measured/", with: "").replacingOccurrences(of: ".MOV", with: "")
            let frame = try #require(loadImage("net-frames/measured-\(name).jpg"))
            let mask = try #require(loadImage("sam3-masks/measured-\(name).png").flatMap(FrameMask.init(image:)))
            let found = NetCornerFinder().find(in: frame, taps: clip.net.corners, mask: mask).corners
            let corners = try found.map { try #require($0, "no corner found in \(name)") }

            let pose = try #require(CameraPose(corners: corners, lens: lens), "no pose in \(name)")

            #expect(abs(pose.heightAboveIce - 61.5) <= 6, "camera height \(pose.heightAboveIce) in for \(name)")
            let tripodToMiddle = hypot(pose.position.x - 36, pose.position.y)   // along the ice, to the goal line's middle (x = 36)
            #expect(abs(tripodToMiddle - 233) <= 12, "tripod to middle of goal line \(tripodToMiddle) in for \(name)")
        }
    }

    /*
    - Four "corners" that sit in a straight line, which no real net could make
    - CameraPose should say it can't tell (nil) instead of making up a phone position
    */
    @Test("says it can't tell when the corners can't be a net")
    func nonsenseCorners() {
        let lens = LensInfo(width: 1920, height: 1080, centerX: 960, centerY: 540, zoom: iPhone1xZoom)
        let inALine = [CGPoint(x: 500, y: 500), CGPoint(x: 600, y: 500), CGPoint(x: 700, y: 500), CGPoint(x: 800, y: 500)]

        #expect(CameraPose(corners: inALine, lens: lens) == nil)
    }
}

// The opening's inside corners in net coordinates: top-left, top-right, bottom-right, bottom-left.
private let insideCorners: [SIMD3<Double>] = [SIMD3(0, 0, 48), SIMD3(72, 0, 48), SIMD3(72, 0, 0), SIMD3(0, 0, 0)]

// A typical iPhone 1x camera (26 mm equivalent) filming 1920 px wide: 1920 × 26 / 36.
private let iPhone1xZoom = 1920.0 * 26 / 36

// A perfect pinhole camera at a known spot, aimed at a known point, with no tilt to the side.
private struct PretendPhone {
    let position: SIMD3<Double>
    let forward: SIMD3<Double>
    let right: SIMD3<Double>
    let down: SIMD3<Double>
    let lens = LensInfo(width: 1920, height: 1080, centerX: 960, centerY: 540, zoom: iPhone1xZoom)

    init(at position: SIMD3<Double>, aimedAt target: SIMD3<Double>) {
        self.position = position
        forward = simd_normalize(target - position)
        right = simd_normalize(simd_cross(SIMD3(0, 0, 1), forward))
        down = simd_cross(right, forward)
    }

    // Where each point would land in this phone's picture, in pixels (y down).
    func picture(of points: [SIMD3<Double>]) -> [CGPoint] {
        points.map { p in
            let d = p - position
            let (x, y, z) = (simd_dot(d, right), simd_dot(d, down), simd_dot(d, forward))
            return CGPoint(x: lens.centerX + lens.zoom * x / z, y: lens.centerY + lens.zoom * y / z)
        }
    }
}

private func degrees(between a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
    acos(min(1, max(-1, simd_dot(simd_normalize(a), simd_normalize(b))))) * 180 / .pi
}

// Wali's hand clicks for one clip.
private struct ClipNet: Decodable {
    struct Spot: Decodable { let x: Double; let y: Double }
    struct Net: Decodable {
        let leftTop: Spot, rightTop: Spot, rightBottom: Spot, leftBottom: Spot
        var corners: [CGPoint] { [leftTop, rightTop, rightBottom, leftBottom].map { CGPoint(x: $0.x, y: $0.y) } }
    }
    let clip: String
    let net: Net
}

private let rinkClips = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("videos/rink-clips")

private func loadAnswers(_ file: String) throws -> [ClipNet] {
    try JSONDecoder().decode([ClipNet].self, from: Data(contentsOf: rinkClips.appendingPathComponent(file)))
}

private func loadImage(_ path: String) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(rinkClips.appendingPathComponent(path) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

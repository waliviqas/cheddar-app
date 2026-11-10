import Testing
import Foundation
import CoreGraphics
import ImageIO
import simd
@testable import CVPipeline

/*
Spots on the ice are in inches, in net coordinates: x runs along the goal line from the left post (0) to the right post (72),
y runs out of the goal toward the shooter. The middle of the goal line is (36, 0).
*/
@Suite("FloorSpot")
struct FloorSpotTests {

    /*
    - A pretend phone 233 in in front of the goal line, 30 in left of the left post, 61.5 in off the ice
    - A spot we picked on the ice (40 in right of the middle, 192 in out) is worked out by math into the phone's picture
    - FloorSpot should turn that pixel back into the same spot on the ice within 1 inch
    */
    @Test("turns a picked spot on the ice back into the same spot")
    func pickedSpot() throws {
        let phone = PretendPhone(at: SIMD3(-30, 233, 61.5), aimedAt: SIMD3(60, 0, 24))
        let floor = try phone.floorSpot()
        let truth = SIMD2(76.0, 192.0)

        let found = try #require(floor.spot(at: phone.picture(of: SIMD3(truth.x, truth.y, 0))))

        #expect(simd_distance(found, truth) <= 1)
    }

    /*
    - Same pretend phone; the bottoms of the two posts sit on the goal line at (0, 0) and (72, 0)
    - FloorSpot should put each one back exactly there, within 1 inch
    */
    @Test("puts the bottoms of the posts on the goal line")
    func postBottoms() throws {
        let phone = PretendPhone(at: SIMD3(-30, 233, 61.5), aimedAt: SIMD3(60, 0, 24))
        let floor = try phone.floorSpot()

        for truth in [SIMD2(0.0, 0.0), SIMD2(72.0, 0.0)] {
            let found = try #require(floor.spot(at: phone.picture(of: SIMD3(truth.x, truth.y, 0))))
            #expect(simd_distance(found, truth) <= 1)
        }
    }

    /*
    - Wali's newest rink clips, with the camera's place worked out from the net (NetCornerFinder + CameraPose)
    - Wali clicked the blue tape he put on the ice as the shooting spot (shot-spots.json), and taped it
      192 in from the middle of the goal line
    - The lens zoom is the typical iPhone 1x value, so it should come out within 12 in
    */
    @Test("measures Wali's blue tape like his tape measure")
    func blueTape() throws {
        for clip in try loadShotSpots() {
            let (floor, _) = try placeCamera(clip.name)

            let tape = try #require(floor.spot(at: clip.tape.point), "tape not on the ice in \(clip.name)")
            let fromGoal = simd_distance(tape, SIMD2(36, 0))

            #expect(abs(fromGoal - 192) <= 12, "tape \(fromGoal) in from the middle of the goal line in \(clip.name)")
        }
    }

    /*
    - A spot high in the sky of the pretend phone's picture, above where the ice ends
    - That line of sight never touches the ice, so FloorSpot should say so (nil) instead of making up a spot
    */
    @Test("says a spot in the sky isn't on the ice")
    func skySpot() throws {
        let phone = PretendPhone(at: SIMD3(-30, 233, 61.5), aimedAt: SIMD3(60, 0, 24))
        let floor = try phone.floorSpot()

        #expect(floor.spot(at: CGPoint(x: 960, y: 0)) == nil)
    }
}

// A typical iPhone 1x camera (26 mm equivalent) filming 1920 px wide.
private let iPhone1xZoom = 1920.0 * 26 / 36
private let iPhoneLens = LensInfo(width: 1920, height: 1080, centerX: 960, centerY: 540, zoom: iPhone1xZoom)

// A perfect pinhole camera at a known spot, aimed at a known point, with no tilt to the side.
private struct PretendPhone {
    let position: SIMD3<Double>
    let forward: SIMD3<Double>
    let right: SIMD3<Double>
    let down: SIMD3<Double>

    init(at position: SIMD3<Double>, aimedAt target: SIMD3<Double>) {
        self.position = position
        forward = simd_normalize(target - position)
        right = simd_normalize(simd_cross(SIMD3(0, 0, 1), forward))
        down = simd_cross(right, forward)
    }

    func picture(of p: SIMD3<Double>) -> CGPoint {
        let d = p - position
        let (x, y, z) = (simd_dot(d, right), simd_dot(d, down), simd_dot(d, forward))
        return CGPoint(x: iPhoneLens.centerX + iPhoneLens.zoom * x / z, y: iPhoneLens.centerY + iPhoneLens.zoom * y / z)
    }

    // The camera's place worked out from the net's inside corners in its picture, like the real app does it.
    func floorSpot() throws -> FloorSpot {
        let corners = [SIMD3(0.0, 0, 48), SIMD3(72.0, 0, 48), SIMD3(72.0, 0, 0), SIMD3(0.0, 0, 0)].map(picture(of:))
        return FloorSpot(pose: try #require(CameraPose(corners: corners, lens: iPhoneLens)), lens: iPhoneLens)
    }
}

// Wali's click on the blue tape for one clip.
private struct ShotSpots: Decodable {
    struct Spot: Decodable { let x: Double; let y: Double; var point: CGPoint { CGPoint(x: x, y: y) } }
    let clip: String
    let tape: Spot
    var name: String { clip.replacingOccurrences(of: "1x-measured/", with: "").replacingOccurrences(of: ".MOV", with: "") }
}

// Wali's inside-corner clicks for the newest clips, used as taps for NetCornerFinder.
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

private func loadShotSpots() throws -> [ShotSpots] {
    try JSONDecoder().decode([ShotSpots].self, from: Data(contentsOf: rinkClips.appendingPathComponent("shot-spots.json")))
}

// Finds the camera's place for one newest clip: NetCornerFinder on the saved frame + SAM 3 mask, then CameraPose.
private func placeCamera(_ name: String) throws -> (FloorSpot, CameraPose) {
    let nets = try JSONDecoder().decode([ClipNet].self, from: Data(contentsOf: rinkClips.appendingPathComponent("net-outline.json")))
    let net = try #require(nets.first { $0.clip.contains(name) }, "no net clicks for \(name)")
    let frame = try #require(loadImage("net-frames/measured-\(name).jpg"))
    let mask = try #require(loadImage("sam3-masks/measured-\(name).png").flatMap(FrameMask.init(image:)))
    let corners = try NetCornerFinder().find(in: frame, taps: net.net.corners, mask: mask).corners.map { try #require($0) }
    let pose = try #require(CameraPose(corners: corners, lens: iPhoneLens))
    return (FloorSpot(pose: pose, lens: iPhoneLens), pose)
}

private func loadImage(_ path: String) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(rinkClips.appendingPathComponent(path) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

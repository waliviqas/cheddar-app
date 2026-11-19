import CoreGraphics
import Foundation
import Testing
import simd
@testable import CVPipeline

@Suite("ShotReader")
struct ShotReaderTests {
    @Test("your Nov 16 net is the size everything is compared with")
    func nov16Size() {
        #expect(abs(ShotReader.netScale(nov16Corners) - 1) <= 0.002)
    }

    @Test("the net looks 0.70 as big from the tester spot")
    func testerSize() {
        #expect(abs(ShotReader.netScale(netCorners(testerPhone())) - 0.70) <= 0.005)
    }

    @Test("the net looks 2.27 times as big from 8 ft away")
    func closeSize() {
        #expect(abs(ShotReader.netScale(netCorners(phone(at: Vec3(36, 96, 40), aim: Vec3(36, 0, 24)))) - 2.27) <= 0.005)
    }

    @Test("tilting the phone doesn't change how big the net looks")
    func tiltedSize() {
        let upright = [Vec2(1000, 200), Vec2(1300, 200), Vec2(1300, 833), Vec2(1000, 833)]
        let angle = 5 * Double.pi / 180, middle = Vec2(1150, 516.5)
        let tilted = upright.map { corner -> Vec2 in
            let offset = corner - middle
            return middle + Vec2(offset.x * cos(angle) - offset.y * sin(angle), offset.x * sin(angle) + offset.y * cos(angle))
        }

        #expect(abs(ShotReader.netScale(upright) - 2) <= 1e-9)
        #expect(abs(ShotReader.netScale(tilted) - 2) <= 1e-9)
    }

    @Test("shots cross your Nov 16 picture left to right")
    func nov16Direction() throws {
        #expect(ShotReader.towardNet(try #require(CameraPose(corners: nov16Corners, lens: iPhone))) == 1)
    }

    @Test("a kid who shoots the other way films from the other side, where shots cross right to left")
    func otherSideDirection() {
        #expect(ShotReader.towardNet(phone(at: Vec3(-190, 115, 61.5), aim: Vec3(36, 0, 24))) == -1)
    }

    @Test("a net left of the middle of the picture still gets the right direction")
    func offCenterDirection() {
        let offCenter = phone(at: Vec3(263, 115, 61.5), aim: Vec3(110, 0, 24))

        #expect(netCorners(offCenter).map(\.x).reduce(0, +) / 4 < 960)
        #expect(ShotReader.towardNet(offCenter) == 1)
    }

    @Test("shots cross the tester spot's picture left to right")
    func testerDirection() {
        #expect(ShotReader.towardNet(testerPhone()) == 1)
    }

    @Test("your Nov 16 strip runs from above the crossbar to below the shooting spot")
    func nov16Strip() throws {
        let pose = try #require(CameraPose(corners: nov16Corners, lens: iPhone))
        let strip = ShotReader.lane(corners: nov16Corners, pose: pose)

        #expect(strip.rows == 508..<941)
        #expect(strip.columns == 150..<1910)
        #expect(strip.rows.contains(Int(nov16Corners[0].y)))
        #expect(strip.rows.contains(Int(pose.pixel(of: Vec3(36, 192, 0)).y)))
    }

    @Test("a net on the left of the picture is searched on the left")
    func leftStrip() throws {
        #expect(try strip(for: phone(at: Vec3(-190, 115, 61.5))).columns == 10..<1770)
    }

    @Test("a phone tipped down moves the strip up to the net")
    func tippedDownStrip() throws {
        #expect(try strip(for: phone(aim: Vec3(36, 60, 0))).rows == 199..<620)
    }

    @Test("the tester spot's strip keeps the crossbar")
    func testerStrip() throws {
        #expect(try strip(for: testerPhone()).rows == 403..<741)
    }

    @Test("the strip stops at the top and bottom of the picture")
    func stripStopsAtEdges() throws {
        #expect(try strip(for: phone(at: Vec3(150, 150, 61.5), aim: Vec3(36, 0, 24))).rows.upperBound == 1080)
        #expect(try strip(for: phone(aim: Vec3(36, 60, -34))).rows.lowerBound == 0)
    }

    @Test("a clean shot on the net counts")
    func cleanShotCounts() {
        #expect(ShotReader.keeps(reading(), scale: 1))
    }

    @Test("a fit miss of 3.0 pixels counts and 3.1 doesn't")
    func fitMissLimit() {
        #expect(ShotReader.keeps(reading(miss: 3.0), scale: 1))
        #expect(!ShotReader.keeps(reading(miss: 3.1), scale: 1))
    }

    @Test("a net twice as big allows a fit miss of 6.0 pixels but not 6.1")
    func closeFitMissLimit() {
        #expect(ShotReader.keeps(reading(miss: 6.0), scale: 2))
        #expect(!ShotReader.keeps(reading(miss: 6.1), scale: 2))
    }

    @Test("a smaller net keeps the 3 pixel limit")
    func farFitMissLimit() {
        #expect(ShotReader.keeps(reading(miss: 3.0), scale: 0.7))
        #expect(!ShotReader.keeps(reading(miss: 3.1), scale: 0.7))
    }

    @Test("5.0 mph counts and 4.9 doesn't")
    func slowestShot() {
        #expect(ShotReader.keeps(reading(mph: 5.0), scale: 1))
        #expect(!ShotReader.keeps(reading(mph: 4.9), scale: 1))
    }

    @Test("130 mph counts and 130.1 doesn't")
    func fastestShot() {
        #expect(ShotReader.keeps(reading(mph: 130), scale: 1))
        #expect(!ShotReader.keeps(reading(mph: 130.1), scale: 1))
    }

    @Test("a dot right at the left post counts and 0.1 in outside doesn't")
    func leftPost() {
        #expect(ShotReader.keeps(reading(across: 0), scale: 1))
        #expect(!ShotReader.keeps(reading(across: -0.1), scale: 1))
    }

    @Test("a dot right at the right post counts and 0.1 in outside doesn't")
    func rightPost() {
        #expect(ShotReader.keeps(reading(across: 72), scale: 1))
        #expect(!ShotReader.keeps(reading(across: 72.1), scale: 1))
    }

    @Test("a dot right at the floor counts and 0.1 in below doesn't")
    func floorEdge() {
        #expect(ShotReader.keeps(reading(up: 0), scale: 1))
        #expect(!ShotReader.keeps(reading(up: -0.1), scale: 1))
    }

    @Test("a dot right at the crossbar counts and 0.1 in over doesn't")
    func crossbar() {
        #expect(ShotReader.keeps(reading(up: 48), scale: 1))
        #expect(!ShotReader.keeps(reading(up: 48.1), scale: 1))
    }

    @Test("one made-up 60 mph shot comes through as one shot")
    func oneShot() throws {
        let shots = ShotReader.shots(in: spotFrames([puckSpots(mph: 60, aim: lowShot, release: 1)]), pose: phone(), scale: 1)
        let shot = try #require(shots.first)

        #expect(shots.count == 1)
        #expect(abs(shot.mph - 59.83) <= 0.01)
        #expect(abs(shot.releaseTime - 1) <= 0.0005)
        #expect(simd_distance(shot.hit, Vec2(35.2, 11.4)) <= 0.1)
    }

    @Test("two shots on the net come through in order, and one that misses wide doesn't")
    func twoShots() {
        let first = puckSpots(mph: 60, aim: lowShot, release: 1), second = puckSpots(mph: 40, aim: Vec3(10, -192, 30), release: 4)
        let wide = puckSpots(mph: 50, aim: Vec3(40, -192, 16), release: 2.5)
        let shots = ShotReader.shots(in: spotFrames([first, wide, second]), pose: phone(), scale: 1)

        #expect(shots.count == 2)
        #expect(zip(shots.map(\.mph), [59.83, 39.66]).allSatisfy { abs($0 - $1) <= 0.01 })
    }

    @Test("a puck flying back out of the net isn't a shot")
    func flyingBackOut() {
        let coming = puckSpots(mph: 60, aim: lowShot, release: 1)
        let going = zip(coming.map(\.t), coming.reversed().map(\.spot)).map { (t: $0, spot: $1) }

        #expect(ShotReader.shots(in: spotFrames([going]), pose: phone(), scale: 1).isEmpty)
    }

    @Test("frames with no puck give no shots")
    func noPuck() {
        #expect(ShotReader.shots(in: spotFrames([]), pose: phone(), scale: 1).isEmpty)
    }

    @Test("a dark puck crossing the search strip is found in each frame")
    func scanFindsPuck() async throws {
        let video = try makeVideo(frames: (0..<24).map { puckPicture(left: 400 + 40 * Double($0), top: 700) }, fps: 240)
        let frames = try await ShotReader.scan(video, lane: (rows: 508..<941, columns: 150..<1910))

        #expect(frames.count == 16)
        #expect(frames.allSatisfy { frame in
            let index = (frame.time * 240).rounded()
            return frame.spots.count == 1 && abs(frame.spots[0].x - (407.5 + 40 * index)) <= 2 && abs(frame.spots[0].y - 707.5) <= 2
        })
    }

    @Test("a dark puck above the search strip is ignored")
    func scanIgnoresAboveStrip() async throws {
        let video = try makeVideo(frames: (0..<24).map { puckPicture(left: 400 + 40 * Double($0), top: 300) }, fps: 240)
        let frames = try await ShotReader.scan(video, lane: (rows: 508..<941, columns: 150..<1910))

        #expect(frames.allSatisfy { $0.spots.isEmpty })
    }

    @Test("your 9 Nov 16 clips read 19 of 20 shots with no extras and an average miss of 2.68 mph or better",
          .enabled(if: realVideosRequested))
    func nov16Clips() async throws {
        let clips = try JSONDecoder().decode([TappedClip].self, from: Data(contentsOf: rinkClips.appendingPathComponent("1x-measured-nov16/net-corners.json")))
        var found = 0, extras = 0, misses: [Double] = []
        for clip in clips {
            let name = URL(fileURLWithPath: clip.clip).deletingPathExtension().lastPathComponent
            let read = try await ShotReader.read(rinkClips.appendingPathComponent(clip.clip), taps: clip.net.taps, lens: iPhone)
            let shots = try #require(read)
            var matched = Set<Int>()
            for known in radarShots where known.clip == name {
                guard let i = shots.indices.first(where: { !matched.contains($0) && abs(shots[$0].releaseTime - known.start) < 0.3 }) else { continue }
                matched.insert(i)
                found += 1
                misses.append(abs(shots[i].mph - known.radar))
            }
            extras += shots.count - matched.count
        }

        #expect(found == 19)
        #expect(extras == 0)
        #expect(misses.reduce(0, +) / Double(misses.count) <= 2.68)
    }

    @Test("your Nov 4 clip with dropped frames still reads both shots", .enabled(if: realVideosRequested))
    func droppedFrameClip() async throws {
        let taps = [Vec2(1503, 608), Vec2(1730, 645), Vec2(1722, 1046), Vec2(1488, 894)]
        let read = try await ShotReader.read(rinkClips.appendingPathComponent("1x-measured/43mph-54mph.MOV"), taps: taps, lens: iPhone)

        #expect(try #require(read).count == 2)
    }

    @Test("4 taps on one spot give no answer")
    func badTaps() async throws {
        let video = try makeVideo(frames: (0..<24).map { puckPicture(left: 400 + 40 * Double($0), top: 700) }, fps: 240)

        #expect(try await ShotReader.read(video, taps: Array(repeating: Vec2(1600, 700), count: 4), lens: iPhone) == nil)
    }
}

private let iPhone = Lens(zoom: 1470.2, centerX: 960, centerY: 540)
private let nov16Corners = [Vec2(1579.4, 538.2), Vec2(1812.8, 562.6), Vec2(1806.8, 926.0), Vec2(1575.8, 807.0)]
private let lowShot = Vec3(-6, -192, 16)
private let realVideosRequested = ProcessInfo.processInfo.environment["CHEDDAR_REAL_VIDEOS"] == "1"
private let rinkClips = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("videos/rink-clips")
private let radarShots: [(clip: String, radar: Double, start: Double)] = [
    ("62mph-55mph", 62, 15.94), ("62mph-55mph", 55, 20.67), ("61mph-57mph-63mph", 61, 10.26), ("61mph-57mph-63mph", 57, 17.85),
    ("61mph-57mph-63mph", 63, 23.84), ("50mph-36mph-59mph", 50, 12.05), ("50mph-36mph-59mph", 36, 17.41), ("50mph-36mph-59mph", 59, 21.52),
    ("30mph-25mph", 30, 18.49), ("30mph-25mph", 25, 23.11), ("67mph-63mph", 67, 19.80), ("67mph-63mph", 63, 23.75),
    ("63mph-62mph", 63, 11.49), ("63mph-62mph", 62, 14.69), ("62mph-72mph", 62, 16.85), ("62mph-72mph", 72, 20.37),
    ("74mph-62mph", 74, 27.10), ("74mph-62mph", 62, 31.65), ("54mph-65mph", 54, 21.28), ("54mph-65mph", 65, 25.59),
]

private struct TappedClip: Decodable {
    struct Point: Decodable { let x: Double, y: Double }
    struct Net: Decodable {
        let leftTop: Point, rightTop: Point, rightBottom: Point, leftBottom: Point
        var taps: [Vec2] { [leftTop, rightTop, rightBottom, leftBottom].map { Vec2($0.x, $0.y) } }
    }
    let clip: String
    let net: Net
}

private func phone(at spot: Vec3 = Vec3(263, 115, 61.5), aim: Vec3 = Vec3(36, 60, 20)) -> CameraPose {
    let forward = simd_normalize(aim - spot)
    let level = simd_normalize(Vec3(-forward.y, forward.x, 0))
    let down = simd_normalize(Vec3(0, 0, -1) + forward.z * forward)
    return CameraPose(position: spot, toCamera: simd_double3x3(rows: [level, down, forward]), lens: iPhone)
}

private func testerPhone() -> CameraPose {
    phone(at: Vec3(335, 110.5, 60), aim: Vec3(36, 0, 24))
}

private func netCorners(_ phone: CameraPose) -> [Vec2] {
    [Vec3(0, 0, 48), Vec3(72, 0, 48), Vec3(72, 0, 0), Vec3(0, 0, 0)].map { phone.pixel(of: $0) }
}

private func strip(for phone: CameraPose) throws -> (rows: Range<Int>, columns: Range<Int>) {
    let corners = netCorners(phone)
    return ShotReader.lane(corners: corners, pose: try #require(CameraPose(corners: corners, lens: iPhone)))
}

private func reading(mph: Double = 60, across: Double = 36, up: Double = 24, miss: Double = 1) -> ShotFitResult {
    ShotFitResult(mph: mph, releaseTime: 1, hit: Vec2(across, up), slid: false, fitMissPx: miss)
}

private func puckSpots(mph: Double, aim: Vec3, release: Double) -> [(t: Double, spot: Vec2)] {
    let step = 1e-5, camera = phone()
    var spot = Vec3(36, 192, 0.75), velocity = simd_normalize(aim) * mph * 17.6, time = 0.0, frame = 2
    var spots: [(t: Double, spot: Vec2)] = []
    while spot.y > -6 && time < 1 {
        if time >= Double(frame) / 240 {
            spots.append((release + Double(frame) / 240, camera.pixel(of: spot)))
            frame += 1
        }
        velocity += step * (Vec3(0, 0, -386.09) - 1.3e-4 * simd_length(velocity) * velocity)
        spot += step * velocity
        time += step
    }
    return spots
}

private func spotFrames(_ shots: [[(t: Double, spot: Vec2)]]) -> [SpotFrame] {
    var byFrame: [Int: [Spot]] = [:]
    for (t, spot) in shots.joined() {
        byFrame[Int((t * 240).rounded()), default: []].append(Spot(x: spot.x, y: spot.y, size: 200))
    }
    return (0..<1440).map { SpotFrame(time: Double($0) / 240, spots: byFrame[$0] ?? [], changed: 0) }
}

private func puckPicture(left: Double, top: Double) -> CGImage {
    let context = CGContext(data: nil, width: 1920, height: 1080, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 1920, height: 1080))
    context.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1))
    context.fill(CGRect(x: left, y: 1080 - top - 16, width: 16, height: 16))
    return context.makeImage()!
}

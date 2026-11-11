import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import CVPipeline

/*
ClackShotReader takes a video and where the camera is (from setting up on the net), and hands back every shot in it:
when the clack was, where the puck sat, how fast it left the stick, and which square of the net it went in.
These run on Wali's real clips and ask the real OpenAI, so each costs a couple of cents.
*/
@Suite("ClackShotReader")
struct ClackShotReaderTests {

    /*
    - The 43mph-54mph clip has 2 shots
    - Both should get a speed, each within 5 mph of the speed measured from the puck's own size (48.6 and 54.2)
    */
    @Test("reads both shots in a clip", .enabled(if: openAIKey != nil))
    func readsBothShots() async throws {
        let shots = try await read("43mph-54mph")

        let withSpeed = shots.filter { $0.mph != nil }
        #expect(withSpeed.count == 2, "got \(withSpeed.map { "\($0.clackTime) s" })")
        let first = try #require(shotNear(8.4, in: shots)?.mph), second = try #require(shotNear(13.95, in: shots)?.mph)
        #expect(abs(first - 48.6) <= 5, "first shot read \(first) mph")
        #expect(abs(second - 54.2) <= 5, "second shot read \(second) mph")
    }

    /*
    - The 43mph-49mph clip: Cheddar follows the first shot fine, but loses the puck on the second
    - The first shot should get a speed; the second should get no speed, rather than a made-up one
    */
    @Test("says no speed instead of guessing when it loses the puck", .enabled(if: openAIKey != nil))
    func noSpeedWhenLost() async throws {
        let shots = try await read("43mph-49mph")

        let first = try #require(shotNear(8.48, in: shots), "no shot found at the first clack")
        #expect(first.mph != nil)
        #expect(shotNear(13.27, in: shots)?.mph == nil, "made up a speed for the lost shot")
    }

    /*
    - The 43mph-54mph clip again; nobody tells it where the puck is
    - For each shot it should pick the puck that actually flies, not the tape or anything else lying around:
      within 15 px of where Wali clicked the puck at each clack, (196, 913) and (237, 905)
    */
    @Test("picks the puck that's shot", .enabled(if: openAIKey != nil))
    func picksTheShotPuck() async throws {
        let shots = try await read("43mph-54mph")

        let first = try #require(shotNear(8.4, in: shots)), second = try #require(shotNear(13.95, in: shots))
        #expect(hypot(first.startSpot.x - 196, first.startSpot.y - 913) <= 15, "picked \(first.startSpot)")
        #expect(hypot(second.startSpot.x - 237, second.startSpot.y - 905) <= 15, "picked \(second.startSpot)")
    }
}

// Reads every shot in one of the measured clips, with the camera placed from Wali's net taps.
private func read(_ clip: String) async throws -> [ClackShotReader.Shot] {
    let (pose, lens) = try placeCamera(clip)
    let reader = ClackShotReader(pose: pose, lens: lens, openAIKey: try #require(openAIKey))
    return try await reader.shots(in: rinkClips.appendingPathComponent("1x-measured/\(clip).MOV"))
}

// The shot whose clack was within a tenth of a second of `seconds`.
private func shotNear(_ seconds: Double, in shots: [ClackShotReader.Shot]) -> ClackShotReader.Shot? {
    shots.first { abs($0.clackTime - seconds) <= 0.1 }
}

// Where the camera is for one clip: Wali's 4 net taps, snapped by NetCornerFinder onto SAM 3's outline, then CameraPose.
private func placeCamera(_ clip: String) throws -> (CameraPose, LensInfo) {
    struct Spot: Decodable { let x: Double; let y: Double }
    struct Net: Decodable { let leftTop: Spot, rightTop: Spot, rightBottom: Spot, leftBottom: Spot }
    struct ClipNet: Decodable { let clip: String; let net: Net }
    let nets = try JSONDecoder().decode([ClipNet].self, from: Data(contentsOf: rinkClips.appendingPathComponent("net-outline.json")))
    let net = try #require(nets.first { $0.clip.contains(clip) }).net
    let taps = [net.leftTop, net.rightTop, net.rightBottom, net.leftBottom].map { CGPoint(x: $0.x, y: $0.y) }
    func image(_ path: String) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithURL(rinkClips.appendingPathComponent(path) as CFURL, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }
    let mask = try #require(FrameMask(image: try image("sam3-masks/measured-\(clip).png")))
    let corners = try NetCornerFinder().find(in: try image("net-frames/measured-\(clip).jpg"), taps: taps, mask: mask).corners.map { try #require($0) }
    let lens = LensInfo(width: 1920, height: 1080, centerX: 960, centerY: 540, zoom: 1475)
    return (try #require(CameraPose(corners: corners, lens: lens)), lens)
}

private let openAIKey = try? String(contentsOf: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cheddar-secrets/openai-key"), encoding: .utf8)
    .trimmingCharacters(in: .whitespacesAndNewlines)

private let rinkClips = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("videos/rink-clips")

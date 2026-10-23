import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import CVPipeline

// One hand-clicked puck position from the answer key.
struct PuckLabel: Decodable {
    let x: Double
    let y: Double
}

// Loads the answer key JSON that ships with the tests.
func loadLabels() throws -> [String: PuckLabel?] {
    let url = Bundle.module.url(forResource: "puck-labels", withExtension: "json", subdirectory: "Resources")!
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([String: PuckLabel?].self, from: data)
}

// Loads one extracted frame image from the videos folder.
func loadFrame(named name: String) -> CGImage? {
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let url = repoRoot.appendingPathComponent("videos/iafrate-frames/\(name)")
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

@Suite("PuckTracker — real footage")
struct RealFootageTests {

    /*
    - Runs the detector on every hand-labeled frame of the real NHL clip
    - A frame counts as found if the answer lands within 10px of the label
    - This test will expect the puck found in at least 80% of labeled frames
    */
    @Test("finds the puck in at least 80% of labeled real frames",
          .disabled("Paused: broadcast footage with no tap isn't how Cheddar works. Replace with Wali's rink clips."))
    func realFootageHitRate() throws {
        let labels = try loadLabels()
        // On broadcast ice the puck blurs to a mid gray about 14px wide, which is what a tap on it reports.
        let tracker = PuckTracker(look: PuckLook(color: CGColor(red: 81 / 255, green: 88 / 255, blue: 96 / 255, alpha: 1), width: 14))
        var hits = 0
        var total = 0

        for (name, label) in labels {
            guard let label else { continue }
            guard let frame = loadFrame(named: name) else { continue }
            total += 1

            guard let found = tracker.detect(in: frame) else { continue }
            let dx = found.x - label.x
            let dy = found.y - (Double(frame.height) - label.y)
            if (dx * dx + dy * dy).squareRoot() <= 10 {
                hits += 1
            }
        }

        try #require(total > 0, "no frames found — re-run the chopper to fill videos/iafrate-frames")
        let hitRate = Double(hits) / Double(total)
        #expect(hitRate >= 0.8, "found the puck in \(hits) of \(total) frames (\(Int(hitRate * 100))%)")
    }
}

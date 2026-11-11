import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import CVPipeline

/*
ReleaseFinder gets the frames from the clack on (each with its real time) and the puck's spot in each frame from
PuckLinker. It finds the moving point (the first frame the puck is more than 4 px from where it sat at the clack),
cuts a close-up around the puck in every frame from 10 before the moving point (never before the clack) to 25 after,
asks OpenAI about all of them at once "is the puck still touching the blade, or has it left?", and hands back the time
of the earliest frame OpenAI says LEFT, as long as the next frame says LEFT too (one stray LEFT doesn't count).
Frame numbers here count from 0 (the clack frame). Pixels are measured from the top-left, y down.
*/
@Suite("ReleaseFinder")
struct ReleaseFinderTests {

    /*
    - 20 frames; the puck starts moving at frame 3, and the fake OpenAI says LEFT from frame 9 on
    - The fake answers later frames faster, so the first answer back isn't the earliest frame
    - ReleaseFinder should hand back frame 9's time
    */
    @Test("picks the earliest frame OpenAI says the puck left")
    func picksEarliestLeft() async throws {
        let openAI = FakeOpenAI(leavesAt: 9)
        let frames = numberedFrames(20)

        let release = try await ReleaseFinder(apiKey: "test-key", send: openAI.send).releaseTime(in: frames, path: puck(movingAt: 3, frames: 20))

        #expect(release == frames[9].seconds)
    }

    /*
    - 20 frames; the puck starts moving at frame 3. The fake OpenAI wrongly says LEFT at frame 5 only, says TOUCHING
      again for 6–8, then LEFT from 9 on (like Terra did once on the 47mph-52mph shot)
    - ReleaseFinder should ignore the lone LEFT at frame 5 and hand back frame 9's time
    */
    @Test("ignores a single stray LEFT")
    func ignoresStrayLeft() async throws {
        let openAI = FakeOpenAI(leavesAt: 9, strayLeft: [5])
        let frames = numberedFrames(20)

        let release = try await ReleaseFinder(apiKey: "test-key", send: openAI.send).releaseTime(in: frames, path: puck(movingAt: 3, frames: 20))

        #expect(release == frames[9].seconds)
    }

    /*
    - 42 frames; the puck sits on the blade until frame 15, then starts moving
    - ReleaseFinder should ask about exactly frames 5 to 40 (10 before the moving point to 25 after), all at once
    */
    @Test("asks about 10 frames before to 25 after the moving point, all at once")
    func asksTheWindowAtOnce() async throws {
        let openAI = FakeOpenAI(leavesAt: 22)

        _ = try await ReleaseFinder(apiKey: "test-key", send: openAI.send).releaseTime(in: numberedFrames(42), path: puck(movingAt: 15, frames: 42))

        #expect(openAI.askedFrames.sorted() == Array(5...40))
        #expect(openAI.mostAtOnce == 36, "only \(openAI.mostAtOnce) questions were out at the same time")
    }

    /*
    - 42 frames; the puck starts moving at frame 1, right after the clack, so 10 frames back would be before the clack
    - ReleaseFinder should start at the clack frame instead: frames 0 to 26
    */
    @Test("never goes back past the clack")
    func startsAtTheClack() async throws {
        let openAI = FakeOpenAI(leavesAt: 9)

        _ = try await ReleaseFinder(apiKey: "test-key", send: openAI.send).releaseTime(in: numberedFrames(42), path: puck(movingAt: 1, frames: 42))

        #expect(openAI.askedFrames.sorted() == Array(0...26))
    }

    /*
    - 2 frames with a red puck-sized square where PuckLinker says the puck is: (450, 150), then (460, 150)
    - Every picture ReleaseFinder sends should be a 260 × 180 close-up with the puck right in the middle
    */
    @Test("sends a close-up centered on the puck")
    func sendsCloseUp() async throws {
        let openAI = FakeOpenAI(leavesAt: 0)
        let spots = [CGPoint(x: 450, y: 150), CGPoint(x: 460, y: 150)]

        _ = try await ReleaseFinder(apiKey: "test-key", send: openAI.send).releaseTime(in: spots.enumerated().map { (frame(withRedSquareAt: $1), Double($0) / 240) }, path: spots)

        #expect(openAI.sentPictures.count == 2)
        for sent in openAI.sentPictures {
            #expect(sent.width == 260)
            #expect(sent.height == 180)
            #expect(isRed(sent, at: CGPoint(x: 130, y: 90)), "the puck isn't in the middle of the close-up")
            #expect(!isRed(sent, at: CGPoint(x: 10, y: 10)))
        }
    }

    /*
    - The puck starts moving at frame 3, but the fake OpenAI says TOUCHING for every frame
    - ReleaseFinder should say it found no release (nil) instead of making one up
    */
    @Test("says no release when OpenAI never sees the puck leave")
    func noRelease() async throws {
        let openAI = FakeOpenAI(leavesAt: nil)

        let release = try await ReleaseFinder(apiKey: "test-key", send: openAI.send).releaseTime(in: numberedFrames(20), path: puck(movingAt: 3, frames: 20))

        #expect(release == nil)
    }

    /*
    - Wali's first shot in the 43mph-54mph clip, the 40 frames from the clack on, asking the real OpenAI
    - Wali checked by eye: the puck leaves the blade at frame 13 (the 13th frame, counting the clack frame as 1)
    - ReleaseFinder should land on frame 13, or at most one frame late. Costs a few cents each run.
    */
    @Test("finds the release in a real shot", .enabled(if: openAIKey != nil))
    func realShot() async throws {
        let clip = rinkClips.appendingPathComponent("1x-measured/43mph-54mph.MOV")
        let clack = 8.401 - 0.0175   // when the clack was heard, minus the time the sound took to reach the phone
        let frames = Array(try await VideoFrameExtractor().frames(from: clip, between: clack, and: clack + 0.3).prefix(40))
        let detector = PuckDetector()
        let path = PuckLinker().path(from: CGPoint(x: 196, y: 913), times: frames.map { $0.seconds - frames[0].seconds }) { i, spot in
            detector.pucks(in: frames[i].image, near: spot)
        }

        let release = try await ReleaseFinder(apiKey: try #require(openAIKey)).releaseTime(in: frames, path: path)

        #expect(release == frames[12].seconds || release == frames[13].seconds, "found \(String(describing: release))")
    }
}

// Pretends to be OpenAI. Each test frame is a solid gray whose shade gives away its number, so the fake knows which
// frame it was asked about and answers LEFT from `leavesAt` on, plus on any `strayLeft` frames (wrong answers). Later frames get answered sooner, like a real server
// that doesn't answer in order.
private final class FakeOpenAI: @unchecked Sendable {
    let leavesAt: Int?
    let strayLeft: Set<Int>
    private let lock = NSLock()
    private var asked: [Int] = []
    private var sent: [CGImage] = []
    private var outNow = 0, mostOut = 0

    init(leavesAt: Int?, strayLeft: Set<Int> = []) { self.leavesAt = leavesAt; self.strayLeft = strayLeft }

    var askedFrames: [Int] { lock.withLock { asked } }
    var sentPictures: [CGImage] { lock.withLock { sent } }
    var mostAtOnce: Int { lock.withLock { mostOut } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let picture = try #require(sentPicture(in: request))
        let number = frameNumber(of: picture)
        lock.withLock {
            sent.append(picture)
            asked.append(number)
            outNow += 1
            mostOut = max(mostOut, outNow)
        }
        try await Task.sleep(nanoseconds: UInt64(max(1, 60 - number)) * 2_000_000)
        lock.withLock { outNow -= 1 }
        let word = leavesAt.map { number >= $0 } == true || strayLeft.contains(number) ? "LEFT" : "TOUCHING"
        let answer: [String: Any] = ["output": [["type": "message", "content": [["type": "output_text", "text": word]]]]]
        return (try JSONSerialization.data(withJSONObject: answer), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }

    // The picture inside an OpenAI Responses request: input → content → input_image → "data:image/jpeg;base64,...".
    private func sentPicture(in request: URLRequest) -> CGImage? {
        guard let body = request.httpBody,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let input = json["input"] as? [[String: Any]],
              let image = input.flatMap({ ($0["content"] as? [[String: Any]]) ?? [] }).first(where: { $0["type"] as? String == "input_image" }),
              let url = image["image_url"] as? String,
              let data = Data(base64Encoded: String(url.drop { $0 != "," }.dropFirst())),
              let source = CGImageSourceCreateWithData(data as CFData, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

// Frames 0, 1, 2... each a solid gray 6 shades lighter than the last, 1/240 s apart.
private func numberedFrames(_ n: Int) -> [(image: CGImage, seconds: Double)] {
    (0..<n).map { i in (draw { $0.setFillColor(gray: CGFloat(i * 6) / 255, alpha: 1); $0.fill(CGRect(x: 0, y: 0, width: 640, height: 360)) }, Double(i) / 240) }
}

private func frameNumber(of picture: CGImage) -> Int {
    Int((Double(pixel(picture, at: CGPoint(x: picture.width / 2, y: picture.height / 2)).red) / 6).rounded())
}

// The puck sits at (300, 200) until `movingAt`, then slides 10 px to the right every frame.
private func puck(movingAt start: Int, frames n: Int) -> [CGPoint?] {
    (0..<n).map { CGPoint(x: 300 + 10 * CGFloat(max(0, $0 - start + 1)), y: 200) }
}

// A gray frame with a red 20 × 20 square centered on `spot` (y down).
private func frame(withRedSquareAt spot: CGPoint) -> CGImage {
    draw { context in
        context.setFillColor(gray: 0.6, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: spot.x - 10, y: 360 - spot.y - 10, width: 20, height: 20))   // the context measures y from the bottom
    }
}

private func draw(_ paint: (CGContext) -> Void) -> CGImage {
    let context = CGContext(data: nil, width: 640, height: 360, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    paint(context)
    return context.makeImage()!
}

private func isRed(_ picture: CGImage, at p: CGPoint) -> Bool {
    let c = pixel(picture, at: p)
    return c.red > 180 && c.green < 80 && c.blue < 80
}

// The color of one pixel (y down).
private func pixel(_ picture: CGImage, at p: CGPoint) -> (red: UInt8, green: UInt8, blue: UInt8) {
    var rgba = [UInt8](repeating: 0, count: 4)
    let context = CGContext(data: &rgba, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(picture, in: CGRect(x: -p.x, y: p.y - CGFloat(picture.height) + 1, width: CGFloat(picture.width), height: CGFloat(picture.height)))
    return (rgba[0], rgba[1], rgba[2])
}

private let openAIKey = try? String(contentsOf: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cheddar-secrets/openai-key"), encoding: .utf8)
    .trimmingCharacters(in: .whitespacesAndNewlines)

private let rinkClips = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("videos/rink-clips")

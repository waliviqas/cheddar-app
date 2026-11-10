import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import CVPipeline

@Suite("FrameMasker")
struct FrameMaskerTests {

    /*
    - A net picture goes to FrameMasker, which talks to a fake SAM 3 instead of the real one
    - It should send the picture and ask SAM 3 for "hockey goal frame", black-and-white result only
    */
    @Test("asks SAM 3 for the hockey goal frame")
    func asksForGoalFrame() async throws {
        let sam = FakeSAM(answer: .mask(try savedMask()))

        _ = try await ReplicateFrameMasker(token: "test-token", send: sam.send).mask(for: try picture())

        let ask = try #require(sam.predictionInput)
        #expect(ask["prompt"] as? String == "hockey goal frame")
        #expect(ask["mask_only"] as? Bool == true)
        #expect(ask["image"] as? String == FakeSAM.uploadedURL)
        #expect(sam.uploadedJPEG)
    }

    /*
    - The fake SAM 3 answers with one of the black-and-white pictures saved from the real SAM 3
    - FrameMasker should hand back a FrameMask the size of the picture, with exactly the white pixels marked as frame
    */
    @Test("turns SAM 3's black-and-white picture into a frame mask")
    func readsTheMask() async throws {
        let saved = try savedMask()
        let sam = FakeSAM(answer: .mask(saved))
        let net = try picture()

        let mask = try await ReplicateFrameMasker(token: "test-token", send: sam.send).mask(for: net)

        let expected = try #require(FrameMask(image: saved))
        #expect(mask.width == net.width)
        #expect(mask.height == net.height)
        #expect(mask.isFrame == expected.isFrame)
    }

    /*
    - The fake SAM 3 reports that it failed
    - FrameMasker should throw SAM 3's own error message instead of handing back an empty frame
    */
    @Test("says so when SAM 3 fails")
    func reportsFailure() async throws {
        let sam = FakeSAM(answer: .failure("out of memory"))

        await #expect(throws: FrameMaskerError.samFailed("out of memory")) {
            _ = try await ReplicateFrameMasker(token: "test-token", send: sam.send).mask(for: try picture())
        }
    }
}

// Pretends to be Replicate: takes the picture upload, answers the SAM 3 request, and serves the result picture.
private final class FakeSAM: @unchecked Sendable {
    enum Answer { case mask(CGImage), failure(String) }
    static let uploadedURL = "https://api.replicate.com/v1/files/fake-upload"
    static let resultURL = "https://replicate.delivery/fake/mask.png"

    let answer: Answer
    private(set) var predictionInput: [String: Any]?
    private(set) var uploadedJPEG = false

    init(answer: Answer) { self.answer = answer }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!.absoluteString
        func reply(_ body: Data) -> (Data, HTTPURLResponse) {
            (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        func json(_ object: [String: Any]) -> (Data, HTTPURLResponse) { reply(try! JSONSerialization.data(withJSONObject: object)) }

        if url.hasSuffix("/v1/files") {
            let body = request.httpBody ?? Data()
            uploadedJPEG = body.range(of: Data("image/jpeg".utf8)) != nil && body.range(of: Data([0xFF, 0xD8, 0xFF])) != nil
            return json(["urls": ["get": FakeSAM.uploadedURL]])
        }
        if url.hasSuffix("/v1/predictions") {
            let sent = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
            predictionInput = sent?["input"] as? [String: Any]
            switch answer {
            case .mask: return json(["id": "p1", "status": "succeeded", "output": FakeSAM.resultURL])
            case .failure(let why): return json(["id": "p1", "status": "failed", "error": why])
            }
        }
        if url == FakeSAM.resultURL, case .mask(let image) = answer {
            return reply(pngData(image))
        }
        throw URLError(.badURL)
    }
}

private let rinkClips = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("videos/rink-clips")

private func loadImage(_ path: String) throws -> CGImage {
    let source = try #require(CGImageSourceCreateWithURL(rinkClips.appendingPathComponent(path) as CFURL, nil))
    return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
}

private func picture() throws -> CGImage { try loadImage("net-frames/measured-43mph-54mph.jpg") }
private func savedMask() throws -> CGImage { try loadImage("sam3-masks/measured-43mph-54mph.png") }

private func pngData(_ image: CGImage) -> Data {
    let data = NSMutableData()
    let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    return data as Data
}

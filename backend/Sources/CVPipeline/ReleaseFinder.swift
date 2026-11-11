import CoreGraphics
import Foundation
import ImageIO

/*
This class's only job is: find the moment the puck leaves the stick, by showing OpenAI a close-up of the puck in each
frame and asking whether it's still touching the blade.
*/
public struct ReleaseFinder: Sendable {
    public typealias Send = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    public enum Failure: Error, Equatable {
        case openAIFailed(String)   // OpenAI's own error message, for debugging
        case unreadableAnswer       // OpenAI answered with something we couldn't make sense of
    }

    static let model = "gpt-6.1-terra"
    static let closeUp = CGSize(width: 260, height: 180)
    static let question = """
        This is a close-up frame from a slow-motion video of a hockey shot. The picture is centered on the puck.

        The puck: a solid, rigid rubber disc, 3 inches across and 1 inch thick. It has a flat top, a flat bottom, and a straight side wall all the way around. It always has real thickness: seen from any angle it looks like a short cylinder or a thick oval with a visible side band, never a flat mark. It is a separate loose object that sits on the surface or flies through the air, and it may look blurred when moving fast.

        The stick: a long straight shaft that ends in a blade. The blade is much longer than the puck (10 to 12 inches), about 3 inches tall, and thin. It is flat or slightly curved and is always attached to the shaft at an angle. The blade's bottom edge runs along the surface when the player shoots.

        The question: look at where the blade and the puck meet.
        - TOUCHING: the blade is in contact with the puck: pressing on its side wall or top, or cupping it.
        - LEFT: there is any space at all between the blade and the puck, even a thin line.

        Answer with exactly one word: TOUCHING or LEFT.
        """

    private let apiKey: String
    private let send: Send

    public init(apiKey: String, send: @escaping Send = ReleaseFinder.overInternet) {
        self.apiKey = apiKey
        self.send = send
    }

    public static let overInternet: Send = { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.unreadableAnswer }
        return (data, http)
    }

    static let framesBefore = 10   // how far before the moving point to start asking (never before the clack)
    static let framesAfter = 25    // how far after it to keep asking

    // `frames` start at the clack, `path` is the puck's spot in each frame from PuckLinker (y down, nil where unseen).
    // Returns the time of the first frame where the puck has left the blade (and the next frame agrees), or nil if never.
    public func releaseTime(in frames: [(image: CGImage, seconds: Double)], path: [CGPoint?]) async throws -> Double? {
        let count = min(frames.count, path.count)
        // The moving point: the first frame the puck is more than 4 px from where it sat at the clack.
        guard let origin = path.first ?? nil,
              let moving = (0..<count).first(where: { i in path[i].map { hypot($0.x - origin.x, $0.y - origin.y) > 4 } ?? false })
        else { return nil }
        let window = max(0, moving - Self.framesBefore)...min(count - 1, moving + Self.framesAfter)

        // Where the puck model missed it (blur), it's still about where it was last seen.
        var spot = origin
        var pictures: [(frame: Int, picture: CGImage)] = []
        for i in 0...window.upperBound {
            if let seen = path[i] { spot = seen }
            if window.contains(i), let picture = closeUp(of: frames[i].image, around: spot) { pictures.append((i, picture)) }
        }

        // Ask about every frame at once; answers come back in any order.
        let left = try await withThrowingTaskGroup(of: (Int, Bool).self) { group in
            for (i, picture) in pictures { group.addTask { (i, try await hasLeft(picture)) } }
            var left: Set<Int> = []
            for try await (i, gone) in group where gone { left.insert(i) }
            return left
        }
        // Before the blade reaches the puck there's a gap too, so a LEFT only counts after the puck was seen touching the
        // blade. The release is the earliest such LEFT that the next frame backs up, so one wrong answer can't start the
        // clock early.
        guard let touched = pictures.map(\.frame).first(where: { !left.contains($0) }) else { return nil }
        return left.sorted().first { $0 > touched && left.contains($0 + 1) }.map { frames[$0].seconds }
    }

    private func closeUp(of image: CGImage, around spot: CGPoint) -> CGImage? {
        let size = Self.closeUp
        let x = min(max(spot.x - size.width / 2, 0), CGFloat(image.width) - size.width)
        let y = min(max(spot.y - size.height / 2, 0), CGFloat(image.height) - size.height)
        return image.cropping(to: CGRect(x: x, y: y, width: size.width, height: size.height))
    }

    private func hasLeft(_ picture: CGImage) async throws -> Bool {
        let jpeg = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(jpeg, "public.jpeg" as CFString, 1, nil) else { throw Failure.unreadableAnswer }
        CGImageDestinationAddImage(dest, picture, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        CGImageDestinationFinalize(dest)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": Self.model,
            "reasoning": ["effort": "none"],   // answer right away, no hidden thinking first: much faster
            "input": [["role": "user", "content": [
                ["type": "input_text", "text": Self.question],
                ["type": "input_image", "image_url": "data:image/jpeg;base64,\((jpeg as Data).base64EncodedString())"],
            ]]],
        ])

        let (data, response) = try await send(request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.unreadableAnswer }
        guard response.statusCode == 200 else {
            throw Failure.openAIFailed((json["error"] as? [String: Any])?["message"] as? String ?? "status \(response.statusCode)")
        }
        let text = ((json["output"] as? [[String: Any]]) ?? [])
            .filter { $0["type"] as? String == "message" }
            .flatMap { ($0["content"] as? [[String: Any]]) ?? [] }
            .compactMap { $0["text"] as? String }
            .joined()
            .uppercased()
        if text.contains("LEFT") { return true }
        if text.contains("TOUCH") { return false }
        throw Failure.unreadableAnswer
    }
}

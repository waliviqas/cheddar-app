import CoreGraphics
import Foundation
import ImageIO

/*
This class's only job is: send a picture of the net to SAM 3 and hand back its colored-in frame as a FrameMask.
*/
public protocol FrameMasker {
    func mask(for picture: CGImage) async throws -> FrameMask
}

public enum FrameMaskerError: Error, Equatable {
    case samFailed(String)      // SAM 3's own error message, for debugging; the app shows the user something friendlier
    case unreadableAnswer       // Replicate answered with something we couldn't make sense of
}

// SAM 3 running on Replicate.
public struct ReplicateFrameMasker: FrameMasker {
    public typealias Send = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    private static let sam3 = "d73db077226443ba4fafd34e233b3626b552eac2a433f90c7c32a9ac89bd9e72"   // mattsays/sam3-image
    private let token: String
    private let send: Send

    public init(token: String, send: @escaping Send = ReplicateFrameMasker.overInternet) {
        self.token = token
        self.send = send
    }

    public static let overInternet: Send = { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FrameMaskerError.unreadableAnswer }
        return (data, http)
    }

    public func mask(for picture: CGImage) async throws -> FrameMask {
        let uploaded = try await upload(picture)

        var answer = try await json(request("https://api.replicate.com/v1/predictions", body: try JSONSerialization.data(withJSONObject: [
            "version": Self.sam3,
            "input": ["image": uploaded, "prompt": "hockey goal frame", "mask_only": true, "return_zip": false],
        ]), contentType: "application/json", wait: true))

        // SAM 3 usually finishes inside the first request; if not, check back until it's done.
        while let status = answer["status"] as? String, status == "starting" || status == "processing" {
            guard let check = (answer["urls"] as? [String: Any])?["get"] as? String else { throw FrameMaskerError.unreadableAnswer }
            try await Task.sleep(nanoseconds: 1_000_000_000)
            answer = try await json(request(check))
        }
        guard answer["status"] as? String == "succeeded" else {
            throw FrameMaskerError.samFailed(answer["error"] as? String ?? answer["status"] as? String ?? "unknown")
        }
        let output = answer["output"] as? String ?? (answer["output"] as? [String])?.first
        guard let output else { throw FrameMaskerError.unreadableAnswer }

        let (data, _) = try await send(request(output, authorized: false))
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let mask = FrameMask(image: resized(image, toMatch: picture))
        else { throw FrameMaskerError.unreadableAnswer }
        return mask
    }

    // Uploads the picture as a JPEG and returns the address Replicate gives it.
    private func upload(_ picture: CGImage) async throws -> String {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else { throw FrameMaskerError.unreadableAnswer }
        CGImageDestinationAddImage(dest, picture, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        CGImageDestinationFinalize(dest)

        let boundary = "cheddar-\(UUID().uuidString)"
        var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"content\"; filename=\"net.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8)
        body.append(data as Data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        let answer = try await json(request("https://api.replicate.com/v1/files", body: body, contentType: "multipart/form-data; boundary=\(boundary)"))
        guard let url = (answer["urls"] as? [String: Any])?["get"] as? String else { throw FrameMaskerError.unreadableAnswer }
        return url
    }

    private func request(_ url: String, body: Data? = nil, contentType: String? = nil, wait: Bool = false, authorized: Bool = true) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        if authorized { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.httpMethod = "POST"
            request.httpBody = body
        }
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        if wait { request.setValue("wait=60", forHTTPHeaderField: "Prefer") }
        return request
    }

    private func json(_ request: URLRequest) async throws -> [String: Any] {
        let (data, _) = try await send(request)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw FrameMaskerError.unreadableAnswer }
        return object
    }

    // SAM 3 can answer at a different size than the picture; stretch it back so pixels line up.
    private func resized(_ image: CGImage, toMatch picture: CGImage) -> CGImage {
        guard image.width != picture.width || image.height != picture.height,
              let context = CGContext(data: nil, width: picture.width, height: picture.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return image }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: picture.width, height: picture.height))
        return context.makeImage() ?? image
    }
}

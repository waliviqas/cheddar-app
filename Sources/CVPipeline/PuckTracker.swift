import CoreGraphics
import Vision

/*
This class's only job is: Image in, puck position out per frame.
*/
public struct PuckTracker {
    public init() {}

    // Runs detect on every frame and bundles the answers into one list.
    // All frames go into track at once and then goes one by one for each.
    public func track(frames: [CGImage]) -> [CGPoint?] {
        return frames.map { detect(in: $0) }
    }

    // Finds the puck in one frame, or nil if there isn't one.
    public func detect(in frame: CGImage) -> CGPoint? {
        let boxes = findShapeBoxes(in: frame)
        guard let box = bestPuckCandidate(from: boxes, in: frame) else { return nil }
        return puckCenter(inside: box, of: frame)
    }

    // Asks Vision to trace every shape in the frame and keeps only the puck-sized boxes.
    private func findShapeBoxes(in frame: CGImage) -> [CGRect] {
        let request = VNDetectContoursRequest()
        request.maximumImageDimension = 1280
        let handler = VNImageRequestHandler(cgImage: frame)
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first else { return [] }

        var boxes: [CGRect] = []
        for i in 0..<observation.contourCount {
            guard let contour = try? observation.contour(at: i) else { continue }
            let bb = contour.normalizedPath.boundingBoxOfPath
            // Vision measures from the bottom-left in 0-1 units; convert to pixels measured from the top.
            let w = bb.width * CGFloat(frame.width)
            let h = bb.height * CGFloat(frame.height)
            let x = bb.minX * CGFloat(frame.width)
            let yTop = CGFloat(frame.height) - (bb.minY + bb.height) * CGFloat(frame.height)
            let box = CGRect(x: x, y: yTop, width: w, height: h).integral
            if looksPuckSized(box) {
                boxes.append(box)
            }
        }
        return boxes
    }

    // A puck shows up as a small box that is not stretched out into a line.
    private func looksPuckSized(_ box: CGRect) -> Bool {
        guard box.width >= 3, box.width <= 40, box.height >= 3, box.height <= 40 else { return false }
        let aspect = box.width / box.height
        return aspect >= 0.33 && aspect <= 4.0
    }

    // Picks the box that looks most like a puck: a dark spot sitting on bright ice.
    private func bestPuckCandidate(from boxes: [CGRect], in frame: CGImage) -> CGRect? {
        var best: (box: CGRect, contrast: Double)?
        for box in boxes {
            let inside = averageBrightness(of: box, in: frame)
            let around = averageBrightness(of: ring(around: box, in: frame), in: frame)
            let contrast = around - inside
            if best == nil || contrast > best!.contrast {
                best = (box, contrast)
            }
        }
        return best?.box
    }

    // The area just outside a box — for a real puck this is bright ice.
    private func ring(around box: CGRect, in frame: CGImage) -> CGRect {
        let grown = box.insetBy(dx: -box.width, dy: -box.height)
        let bounds = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        return grown.intersection(bounds).integral
    }

    // The average brightness of one region of the frame.
    private func averageBrightness(of box: CGRect, in frame: CGImage) -> Double {
        guard box.width >= 1, box.height >= 1,
              let crop = frame.cropping(to: box),
              let pixels = readPixels(from: crop) else { return 0 }
        var sum = 0
        var i = 0
        while i < pixels.count {
            sum += Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])
            i += 4
        }
        let count = pixels.count / 4
        return count > 0 ? Double(sum) / Double(count) : 0
    }

    // Pinpoints the puck's center inside its box by averaging the dark pixels.
    private func puckCenter(inside box: CGRect, of frame: CGImage) -> CGPoint? {
        guard let crop = frame.cropping(to: box),
              let pixels = readPixels(from: crop) else { return nil }
        var sumX = 0.0
        var sumY = 0.0
        var count = 0
        for row in 0..<crop.height {
            for col in 0..<crop.width {
                let i = (row * crop.width + col) * 4
                let brightness = Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])
                if brightness < 384 {
                    sumX += Double(col) + 0.5
                    sumY += Double(row) + 0.5
                    count += 1
                }
            }
        }
        guard count > 0 else {
            return CGPoint(x: box.midX, y: Double(frame.height) - box.midY)
        }
        let x = Double(box.minX) + sumX / Double(count)
        let yTop = Double(box.minY) + sumY / Double(count)
        return CGPoint(x: x, y: Double(frame.height) - yTop)
    }

    // Unpacks an image into a list of every pixel's color.
    private func readPixels(from frame: CGImage) -> [UInt8]? {
        guard let ctx = CGContext(
            data: nil,
            width: frame.width, height: frame.height,
            bitsPerComponent: 8, bytesPerRow: frame.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(frame, in: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        guard let data = ctx.data else { return nil }
        let buffer = data.bindMemory(to: UInt8.self, capacity: frame.width * frame.height * 4)
        return Array(UnsafeBufferPointer(start: buffer, count: frame.width * frame.height * 4))
    }
}

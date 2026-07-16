import CoreGraphics
import CoreMedia
import CoreVideo
import Vision

/*
This class's only job is: Image in, puck position out per frame.
*/
public struct PuckTracker {
    public init() {}

    // Tries Apple's trajectory detector first — it needs a long enough flight to speak up.
    // Footage too short for it falls back to our own lock-on logic.
    public func track(frames: [CGImage]) -> [CGPoint?] {
        if let flight = trajectoryPath(through: frames) {
            return flight
        }
        return lockOnTrack(frames: frames)
    }

    // Reports every separate flight Vision saw, each as its own path of points.
    // Vision names each trajectory it follows, so points are grouped by that name — never mixed.
    public func flights(in frames: [CGImage]) -> [[CGPoint]] {
        let request = VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: 5)
        var flightsByName: [UUID: [CGPoint]] = [:]
        var order: [UUID] = []

        for (index, frame) in frames.enumerated() {
            guard let sample = makeSampleBuffer(from: frame, index: index) else { continue }
            let handler = VNImageRequestHandler(cmSampleBuffer: sample, orientation: .up, options: [:])
            try? handler.perform([request])

            for trajectory in request.results ?? [] {
                let points = trajectory.detectedPoints.map {
                    CGPoint(x: $0.x * Double(frame.width), y: $0.y * Double(frame.height))
                }
                if flightsByName[trajectory.uuid] == nil {
                    order.append(trajectory.uuid)
                    flightsByName[trajectory.uuid] = points
                } else if let newest = points.last {
                    flightsByName[trajectory.uuid]?.append(newest)
                }
            }
        }
        return order.compactMap { flightsByName[$0] }
    }

    // Feeds the frames to Vision's projectile detector and reads the flight path back.
    private func trajectoryPath(through frames: [CGImage]) -> [CGPoint?]? {
        let request = VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: 5)
        var path: [CGPoint?] = []
        var sawTrajectory = false

        for (index, frame) in frames.enumerated() {
            guard let sample = makeSampleBuffer(from: frame, index: index) else {
                path.append(nil)
                continue
            }
            let handler = VNImageRequestHandler(cmSampleBuffer: sample, orientation: .up, options: [:])
            try? handler.perform([request])

            let best = (request.results ?? []).max { $0.detectedPoints.count < $1.detectedPoints.count }
            if let last = best?.detectedPoints.last {
                path.append(CGPoint(x: last.x * Double(frame.width), y: last.y * Double(frame.height)))
                sawTrajectory = true
            } else {
                path.append(nil)
            }
        }
        return sawTrajectory ? path : nil
    }

    // Wraps one image in the timestamped container Vision's trajectory detector requires.
    private func makeSampleBuffer(from frame: CGImage, index: Int) -> CMSampleBuffer? {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, frame.width, frame.height, kCVPixelFormatType_32ARGB, nil, &pixelBuffer)
        guard let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: frame.width, height: frame.height,
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) {
            ctx.draw(frame, in: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        var formatDescription: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)
        guard let formatDescription else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime(value: CMTimeValue(index), timescale: 30),
            decodeTimeStamp: .invalid
        )
        var sample: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: nil,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sample
        )
        return sample
    }

    // Reports nil until something proves it is really moving, then locks on and follows it.
    private func lockOnTrack(frames: [CGImage]) -> [CGPoint?] {
        var path: [CGPoint?] = []
        var lastKnown: CGPoint?
        var previous: CGPoint?
        var restingBoxes: [CGRect] = []
        var suspects: [(spot: CGPoint, step: CGVector)] = []

        for frame in frames {
            if lastKnown == nil {
                let boxes = findShapeBoxes(in: frame)
                var locked: (spot: CGPoint, from: CGPoint)?

                if let confirmed = confirmedMover(among: suspects, in: boxes, of: frame) {
                    locked = confirmed
                } else {
                    let movers = freshMovers(in: boxes, since: restingBoxes, of: frame)
                    if movers.count == 1 {
                        locked = movers[0]
                    } else if movers.count >= 2 {
                        suspects = movers.map {
                            (spot: $0.spot, step: CGVector(dx: $0.spot.x - $0.from.x, dy: $0.spot.y - $0.from.y))
                        }
                    }
                }

                if let locked {
                    suspects = []
                    previous = locked.from
                    lastKnown = locked.spot
                    path.append(locked.spot)
                } else {
                    path.append(nil)
                }
                restingBoxes = boxes
            } else {
                let found = detect(in: frame, near: expectedSpot(lastKnown: lastKnown, previous: previous))
                path.append(found)
                if let found {
                    previous = lastKnown
                    lastKnown = found
                }
            }
        }
        return path
    }

    // Everything that slid a real distance since last frame, with where it slid from.
    // Tiny jitters and boxes appearing out of nowhere both stay out.
    private func freshMovers(in boxes: [CGRect], since restingBoxes: [CGRect], of frame: CGImage) -> [(spot: CGPoint, from: CGPoint)] {
        guard !restingBoxes.isEmpty else { return [] }
        var movers: [(spot: CGPoint, from: CGPoint)] = []
        for box in boxes {
            guard let nearest = restingBoxes.min(by: { moveDistance(from: $0, to: box) < moveDistance(from: $1, to: box) }) else { continue }
            let slid = moveDistance(from: nearest, to: box)
            guard slid > 5, slid <= 200, let spot = puckCenter(inside: box, of: frame) else { continue }
            let from = CGPoint(x: nearest.midX, y: Double(frame.height) - nearest.midY)
            movers.append((spot: spot, from: from))
        }
        return movers
    }

    // A suspect that kept moving the same way it was already going is the real mover.
    private func confirmedMover(among suspects: [(spot: CGPoint, step: CGVector)], in boxes: [CGRect], of frame: CGImage) -> (spot: CGPoint, from: CGPoint)? {
        var best: (spot: CGPoint, from: CGPoint, offBy: Double)?
        for suspect in suspects {
            let expected = CGPoint(x: suspect.spot.x + suspect.step.dx, y: suspect.spot.y + suspect.step.dy)
            let stepLength = (suspect.step.dx * suspect.step.dx + suspect.step.dy * suspect.step.dy).squareRoot()
            let allowed = stepLength / 2 + 10
            for box in boxes {
                let dx = box.midX - expected.x
                let dy = (Double(frame.height) - box.midY) - expected.y
                let offBy = (dx * dx + dy * dy).squareRoot()
                guard offBy <= allowed, let spot = puckCenter(inside: box, of: frame) else { continue }
                if best == nil || offBy < best!.offBy {
                    best = (spot: spot, from: suspect.spot, offBy: offBy)
                }
            }
        }
        guard let best else { return nil }
        return (spot: best.spot, from: best.from)
    }

    // How far apart the centers of two boxes are.
    private func moveDistance(from a: CGRect, to b: CGRect) -> Double {
        let dx = a.midX - b.midX
        let dy = a.midY - b.midY
        return (dx * dx + dy * dy).squareRoot()
    }

    // Where the puck should be by now: its last spot plus the way it was moving.
    private func expectedSpot(lastKnown: CGPoint?, previous: CGPoint?) -> CGPoint? {
        guard let lastKnown else { return nil }
        guard let previous else { return lastKnown }
        return CGPoint(
            x: lastKnown.x + (lastKnown.x - previous.x),
            y: lastKnown.y + (lastKnown.y - previous.y)
        )
    }

    // Finds the puck in one frame, or nil if there isn't one.
    public func detect(in frame: CGImage) -> CGPoint? {
        return detect(in: frame, near: nil)
    }

    // Finds the puck in one frame, sticking near the last known spot when there is one.
    private func detect(in frame: CGImage, near lastKnown: CGPoint?) -> CGPoint? {
        let boxes = findShapeBoxes(in: frame)
        let chosen: CGRect?
        if let lastKnown {
            chosen = nearestBox(to: lastKnown, from: boxes, in: frame)
        } else {
            chosen = bestPuckCandidate(from: boxes, in: frame)
        }
        guard let chosen else { return nil }
        return puckCenter(inside: chosen, of: frame)
    }

    // Picks the box whose center is closest to the last known puck position.
    private func nearestBox(to point: CGPoint, from boxes: [CGRect], in frame: CGImage) -> CGRect? {
        var best: (box: CGRect, distance: Double)?
        for box in boxes {
            let dx = box.midX - point.x
            let dy = (Double(frame.height) - box.midY) - point.y
            let distance = dx * dx + dy * dy
            if best == nil || distance < best!.distance {
                best = (box, distance)
            }
        }
        return best?.box
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

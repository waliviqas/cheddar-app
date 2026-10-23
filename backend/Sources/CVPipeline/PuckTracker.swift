import CoreGraphics
import CoreMedia
import CoreVideo
import Vision

/*
This class's only job is: Image in, puck position out per frame.
*/
public struct PuckTracker {
    // What the puck looks like, from the setup tap. PuckShapeFinder uses it to spot the puck in every frame.
    public let look: PuckLook

    public init(look: PuckLook) {
        self.look = look
    }

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

    // Asks PuckShapeFinder for everything in the frame that looks like the puck.
    // PuckShapeFinder measures y from the bottom; this file's boxes measure it from the top.
    private func findShapeBoxes(in frame: CGImage) -> [CGRect] {
        return PuckShapeFinder().pucks(in: frame, like: look).map {
            CGRect(x: $0.minX, y: Double(frame.height) - $0.maxY, width: $0.width, height: $0.height)
        }
    }

    // PuckShapeFinder lists the boxes that stand out most from their surroundings first, so take the first.
    private func bestPuckCandidate(from boxes: [CGRect], in frame: CGImage) -> CGRect? {
        return boxes.first
    }

    // The puck's center is the center of its box, with y measured from the bottom.
    private func puckCenter(inside box: CGRect, of frame: CGImage) -> CGPoint? {
        return CGPoint(x: box.midX, y: Double(frame.height) - box.midY)
    }
}

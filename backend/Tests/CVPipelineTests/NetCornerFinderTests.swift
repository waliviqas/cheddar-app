import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import CVPipeline

@Suite("NetCornerFinder")
struct NetCornerFinderTests {

    /*
    - A drawn net with square corners, plus its colored-in frame (what SAM 3 would hand back)
    - The opening's corners are at (412,212), (788,212), (788,467), (412,467); taps are about 15 px off
    - Every corner should land within 2 px, and the outline should trace the whole inside edge within 2 px
    */
    @Test("finds the corners and outline of a square net")
    func squareNet() throws {
        let net = drawNet(cornerRadius: 0)
        let shape = NetCornerFinder().find(in: net, taps: sloppyTaps, mask: try frameMask(of: net))

        for (corner, truth) in zip(shape.corners, drawnCorners) {
            #expect(distance(try #require(corner), truth) <= 2)
        }
        expectTraces(shape.outline, insideEdge(cornerRadius: 0), within: 2)
    }

    /*
    - Same net, but the top corners are rounded (30 px radius on the outside edge)
    - The top corners should land where the straight inside edges would meet, not on the curve
    - The outline should follow the inside of the bend, within 2 px
    */
    @Test("finds the corners and outline of a rounded net")
    func roundedNet() throws {
        let net = drawNet(cornerRadius: 30)
        let shape = NetCornerFinder().find(in: net, taps: sloppyTaps, mask: try frameMask(of: net))

        for (corner, truth) in zip(shape.corners, drawnCorners) {
            #expect(distance(try #require(corner), truth) <= 2)
        }
        expectTraces(shape.outline, insideEdge(cornerRadius: 30), within: 2)
    }

    /*
    - The square net again, but the colored-in frame also has a stray blob in the middle of the opening
      (like SAM 3 coloring a letter on the boards)
    - The blob isn't joined to the frame, so it should be ignored: same corners and outline as the clean net
    */
    @Test("ignores stray specks in the colored-in frame")
    func ignoresSpecks() throws {
        let net = drawNet(cornerRadius: 0)
        let clean = try frameMask(of: net)
        var isFrame = clean.isFrame
        for y in 300..<340 { for x in 560..<620 { isFrame[y * clean.width + x] = true } }
        let speckled = FrameMask(width: clean.width, height: clean.height, isFrame: isFrame)

        let shape = NetCornerFinder().find(in: net, taps: sloppyTaps, mask: speckled)

        for (corner, truth) in zip(shape.corners, drawnCorners) {
            #expect(distance(try #require(corner), truth) <= 2)
        }
        expectTraces(shape.outline, insideEdge(cornerRadius: 0), within: 2)
    }

    /*
    - One frame from each of Wali's 5 older rink clips (sunny, posts dark in shade), with SAM 3's saved colored-in frame
    - Answer sheet: the inside corners Wali clicked by hand (net-corners.json)
    - Taps are the answer moved about 15 px off; every corner should land within 6 px
    */
    @Test("finds the net corners in the older rink clips")
    func olderClips() throws {
        for clip in try loadAnswers("net-corners.json") {
            let name = clip.clip.replacingOccurrences(of: "1x/", with: "").replacingOccurrences(of: ".MOV", with: "")
            let frame = try #require(loadImage("net-frames/\(name).jpg"))
            let mask = try #require(loadImage("sam3-masks/\(name).png").flatMap(FrameMask.init(image:)))
            let answers = clip.net.corners

            let shape = NetCornerFinder().find(in: frame, taps: tapsNear(answers), mask: mask)

            for (corner, answer) in zip(shape.corners, answers) {
                let corner = try #require(corner, "no corner near \(answer) in \(name)")
                #expect(distance(corner, answer) <= 6, "corner off by \(distance(corner, answer)) px in \(name)")
            }
        }
    }

    /*
    - One frame from 3 of Wali's newest rink clips (overcast), with SAM 3's saved colored-in frame
    - Answer sheet: Wali's inside-corner clicks plus 3 clicks on the inside of each top bend (net-outline.json)
    - Every corner should land within 6 px; the outline should pass within 4 px of every bend click
    */
    @Test("finds the net corners and outline in the newest rink clips")
    func newestClips() throws {
        for clip in try loadAnswers("net-outline.json") {
            let name = clip.clip.replacingOccurrences(of: "1x-measured/", with: "").replacingOccurrences(of: ".MOV", with: "")
            let frame = try #require(loadImage("net-frames/measured-\(name).jpg"))
            let mask = try #require(loadImage("sam3-masks/measured-\(name).png").flatMap(FrameMask.init(image:)))
            let answers = clip.net.corners

            let shape = NetCornerFinder().find(in: frame, taps: tapsNear(answers), mask: mask)

            for (corner, answer) in zip(shape.corners, answers) {
                let corner = try #require(corner, "no corner near \(answer) in \(name)")
                #expect(distance(corner, answer) <= 6, "corner off by \(distance(corner, answer)) px in \(name)")
            }
            for click in clip.net.bendClicks {
                let nearest = shape.outline.map { distance($0, click) }.min() ?? .infinity
                #expect(nearest <= 4, "outline misses the bend click \(click) by \(nearest) px in \(name)")
            }
        }
    }

    /*
    - Three good taps and one tap out on empty ice, far from the net
    - The good ones should be found; the bad one should come back as nil instead of snapping to something random
    */
    @Test("says so when a tap isn't near the net")
    func badTap() throws {
        let net = drawNet(cornerRadius: 0)
        let taps = Array(sloppyTaps.prefix(3)) + [CGPoint(x: 120, y: 650)]

        let shape = NetCornerFinder().find(in: net, taps: taps, mask: try frameMask(of: net))

        #expect(shape.corners.count == 4)
        for corner in shape.corners.prefix(3) {
            #expect(corner != nil)
        }
        #expect(shape.corners[3] == nil)
    }
}

// The drawn net's true inside corners (the opening): top-left, top-right, bottom-right, bottom-left.
private let drawnCorners = [CGPoint(x: 412, y: 212), CGPoint(x: 788, y: 212), CGPoint(x: 788, y: 467), CGPoint(x: 412, y: 467)]
private let sloppyTaps = [CGPoint(x: 401, y: 224), CGPoint(x: 800, y: 201), CGPoint(x: 777, y: 478), CGPoint(x: 424, y: 455)]

// A 1280×720 fake frame: light ice, two red posts and a red crossbar 12 px thick, no bottom bar.
// `cornerRadius` is the bend on the outside edge of the top corners (0 = square).
private func drawNet(cornerRadius: CGFloat) -> CGImage {
    let width = 1280, height = 720
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Flip so y counts down from the top, like the video.
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)

    context.setFillColor(red: 0.78, green: 0.83, blue: 0.88, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // The path runs down the middle of the 12 px tube, 6 px inside the outside edge.
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 406, y: 467))
    path.addArc(tangent1End: CGPoint(x: 406, y: 206), tangent2End: CGPoint(x: 794, y: 206), radius: max(cornerRadius - 6, 0))
    path.addArc(tangent1End: CGPoint(x: 794, y: 206), tangent2End: CGPoint(x: 794, y: 467), radius: max(cornerRadius - 6, 0))
    path.addLine(to: CGPoint(x: 794, y: 467))

    context.addPath(path)
    context.setStrokeColor(red: 0.7, green: 0.1, blue: 0.15, alpha: 1)
    context.setLineWidth(12)
    context.setLineCap(.butt)
    context.setLineJoin(.miter)
    context.strokePath()

    return context.makeImage()!
}

// The colored-in frame SAM 3 would give for a drawn net: every red pixel.
private func frameMask(of net: CGImage) throws -> FrameMask {
    let width = net.width, height = net.height
    var rgba = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(data: &rgba, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(net, in: CGRect(x: 0, y: 0, width: width, height: height))
    let isFrame = (0..<(width * height)).map { i in Int(rgba[i * 4]) - Int(rgba[i * 4 + 1]) > 60 }
    return FrameMask(width: width, height: height, isFrame: isFrame)
}

// The true inside edge of the drawn net, one dot per pixel: up the left post, across, down the right post.
private func insideEdge(cornerRadius: CGFloat) -> [CGPoint] {
    let r = max(cornerRadius - 12, 0)   // the bend on the inside edge is 12 px tighter than on the outside
    var dots: [CGPoint] = []
    for y in stride(from: 467, through: 212 + r, by: -1) { dots.append(CGPoint(x: 412, y: y)) }
    for step in 0...90 where r > 0 {
        let a = CGFloat(step) * .pi / 180
        dots.append(CGPoint(x: 412 + r - r * cos(a), y: 212 + r - r * sin(a)))
    }
    for x in stride(from: 412 + r, through: 788 - r, by: 1) { dots.append(CGPoint(x: x, y: 212)) }
    for step in 0...90 where r > 0 {
        let a = CGFloat(step) * .pi / 180
        dots.append(CGPoint(x: 788 - r + r * sin(a), y: 212 + r - r * cos(a)))
    }
    for y in stride(from: 212 + r, through: 467, by: 1) { dots.append(CGPoint(x: 788, y: y)) }
    return dots
}

// Every outline dot must sit on the true edge, and every part of the true edge must have an outline dot nearby,
// so a handful of dots in one spot can't pass.
private func expectTraces(_ outline: [CGPoint], _ edge: [CGPoint], within limit: Double,
                          sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(!outline.isEmpty, "outline is empty", sourceLocation: sourceLocation)
    let offEdge = outline.filter { dot in edge.map { distance(dot, $0) }.min()! > limit }
    #expect(offEdge.isEmpty, "\(offEdge.count) outline dots are off the edge, e.g. \(offEdge.first.map { "\($0)" } ?? "")", sourceLocation: sourceLocation)
    let checkpoints = stride(from: 0, to: edge.count, by: 20).map { edge[$0] }
    let missed = checkpoints.filter { spot in (outline.map { distance(spot, $0) }.min() ?? .infinity) > limit + 1 }
    #expect(missed.isEmpty, "outline skips \(missed.count) of \(checkpoints.count) stretches of the edge, e.g. near \(missed.first.map { "\($0)" } ?? "")", sourceLocation: sourceLocation)
}

private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
    Double(((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot())
}

// The answer moved about 15 px off in a different direction per corner, like a sloppy tap.
private func tapsNear(_ answers: [CGPoint]) -> [CGPoint] {
    let offsets = [CGPoint(x: -11, y: 10), CGPoint(x: 12, y: -9), CGPoint(x: 10, y: 11), CGPoint(x: -12, y: -9)]
    return zip(answers, offsets).map { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
}

// Wali's hand clicks for one clip. The newest clips also have 3 clicks on the inside of each top bend.
private struct ClipNet: Decodable {
    struct Spot: Decodable { let x: Double; let y: Double }
    struct Net: Decodable {
        let leftTop: Spot, rightTop: Spot, rightBottom: Spot, leftBottom: Spot
        let leftCurve: [Spot]?, rightCurve: [Spot]?

        var corners: [CGPoint] { [leftTop, rightTop, rightBottom, leftBottom].map { CGPoint(x: $0.x, y: $0.y) } }
        var bendClicks: [CGPoint] { ((leftCurve ?? []) + (rightCurve ?? [])).map { CGPoint(x: $0.x, y: $0.y) } }
    }
    let clip: String
    let net: Net
}

private let rinkClips = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("videos/rink-clips")

private func loadAnswers(_ file: String) throws -> [ClipNet] {
    try JSONDecoder().decode([ClipNet].self, from: Data(contentsOf: rinkClips.appendingPathComponent(file)))
}

private func loadImage(_ path: String) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(rinkClips.appendingPathComponent(path) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

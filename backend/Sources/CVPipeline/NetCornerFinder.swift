import CoreGraphics
import Foundation

/*
This class's only job is: turn 4 rough taps plus SAM 3's colored-in frame into the net's exact inside corners
and the outline of its opening (straight posts down to the ice, rounded at the top).
*/
public struct NetCornerFinder {
    public init() {}

    // Taps and corners go top-left, top-right, bottom-right, bottom-left, in pixels (y down).
    // A corner is nil when there's no net near that tap.
    public func find(in frame: CGImage, taps: [CGPoint], mask: FrameMask) -> NetShape {
        guard taps.count == 4, let photo = Photo(frame), photo.width == mask.width, photo.height == mask.height else {
            return NetShape(corners: [nil, nil, nil, nil], outline: [])
        }
        let net = Frame(mask: mask, photo: photo)
        let (tl, tr, br, bl) = (taps[0], taps[1], taps[2], taps[3])

        let leftPost = net.postLine(top: tl, bottom: bl, outward: -1)
            ?? net.postLine(top: tl, bottom: CGPoint(x: tl.x, y: tl.y + 200), outward: -1)
            ?? net.postLine(top: CGPoint(x: bl.x, y: bl.y - 200), bottom: bl, outward: -1)
        let rightPost = net.postLine(top: tr, bottom: br, outward: 1)
            ?? net.postLine(top: tr, bottom: CGPoint(x: tr.x, y: tr.y + 200), outward: 1)
            ?? net.postLine(top: CGPoint(x: br.x, y: br.y - 200), bottom: br, outward: 1)
        let crossbar = net.crossbarLine(left: tl, right: tr)

        var corners: [CGPoint?] = [nil, nil, nil, nil]
        if let crossbar {
            corners[0] = leftPost.map { meet(post: $0, bar: crossbar) }.flatMap { near($0, tl) }
            corners[1] = rightPost.map { meet(post: $0, bar: crossbar) }.flatMap { near($0, tr) }
        }
        corners[2] = rightPost.flatMap { net.ice(post: $0, near: br, outward: 1) }.flatMap { near($0, br) }
        corners[3] = leftPost.flatMap { net.ice(post: $0, near: bl, outward: -1) }.flatMap { near($0, bl) }

        // Outline: up the left post from the ice, around the top-left bend, across, around the top-right bend, down to the ice.
        var outline: [CGPoint] = []
        if let leftPost, let rightPost, let crossbar, let topLeft = corners[0], let topRight = corners[1] {
            let leftBend = net.bend(at: topLeft, post: leftPost, bar: crossbar, side: 1)
            let rightBend = net.bend(at: topRight, post: rightPost, bar: crossbar, side: -1)
            let path = [corners[3] ?? CGPoint(x: leftPost.at(bl.y), y: bl.y)]
                + (leftBend.isEmpty ? [topLeft] : leftBend)
                + (rightBend.isEmpty ? [topRight] : rightBend)
                + [corners[2] ?? CGPoint(x: rightPost.at(br.y), y: br.y)]
            outline = dotted(path)
        }
        return NetShape(corners: corners, outline: outline)
    }

    // Where a post's straight inside edge meets the crossbar's.
    private func meet(post: Line, bar: Line) -> CGPoint {
        // post: x = a + b·y, bar: y = a + b·x
        let x = (post.a + post.b * bar.a) / (1 - post.b * bar.b)
        return CGPoint(x: x, y: bar.a + bar.b * x)
    }

    // A corner only counts if it's near its tap; otherwise the tap wasn't on this corner.
    private func near(_ corner: CGPoint, _ tap: CGPoint) -> CGPoint? {
        hypot(corner.x - tap.x, corner.y - tap.y) <= 40 ? corner : nil
    }

    // Fills in a dot every pixel along the path, so the outline has no gaps.
    private func dotted(_ path: [CGPoint]) -> [CGPoint] {
        var dots: [CGPoint] = []
        for (a, b) in zip(path, path.dropFirst()) {
            let steps = max(1, Int(hypot(b.x - a.x, b.y - a.y).rounded(.up)))
            for i in 0..<steps {
                let t = CGFloat(i) / CGFloat(steps)
                dots.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        if let last = path.last { dots.append(last) }
        return dots
    }
}

public struct NetShape {
    // The opening's corners: where the straight inside edges meet at the top, where the posts reach the ice at the bottom.
    public let corners: [CGPoint?]
    // Dots along the inside of the opening: up the left post, around the top, down the right post. NetGrid draws inside these.
    public let outline: [CGPoint]

    public init(corners: [CGPoint?], outline: [CGPoint]) {
        self.corners = corners
        self.outline = outline
    }
}

// A straight line. For a post, t is y and the line sits at x = a + b·t; for the crossbar, t is x and y = a + b·t.
struct Line {
    let a: Double
    let b: Double
    func at(_ t: Double) -> Double { a + b * t }
    func at(_ t: CGFloat) -> CGFloat { CGFloat(a + b * Double(t)) }
}

// The picture's colors, to nudge edges onto the exact spot where the red frame meets the netting.
struct Photo {
    let width: Int, height: Int
    private let rgba: [UInt8]

    init?(_ image: CGImage) {
        width = image.width
        height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        rgba = data
    }

    func color(_ x: Int, _ y: Int) -> (Int, Int, Int)? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let i = (y * width + x) * 4
        return (Int(rgba[i]), Int(rgba[i + 1]), Int(rgba[i + 2]))
    }

    // How big the color change is between two neighboring pixels.
    func jump(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) -> Int {
        guard x0 >= 0, y0 >= 0, x1 >= 0, y1 >= 0, x0 < width, x1 < width, y0 < height, y1 < height else { return 0 }
        let i = (y0 * width + x0) * 4, j = (y1 * width + x1) * 4
        return abs(Int(rgba[i]) - Int(rgba[j])) + abs(Int(rgba[i + 1]) - Int(rgba[j + 1])) + abs(Int(rgba[i + 2]) - Int(rgba[j + 2]))
    }
}

// SAM 3's colored-in frame, cleaned up (only the biggest connected piece), plus the photo for fine-tuning edges.
struct Frame {
    let width: Int, height: Int
    private let isFrame: [Bool]
    private let photo: Photo

    init(mask: FrameMask, photo: Photo) {
        width = mask.width
        height = mask.height
        self.photo = photo
        isFrame = Frame.biggestPiece(of: mask)
    }

    // Keeps only the largest joined-up blob, so specks SAM colored on letters or netting are dropped.
    private static func biggestPiece(of mask: FrameMask) -> [Bool] {
        let w = mask.width, h = mask.height
        var label = [Int32](repeating: 0, count: w * h)
        var biggest: (id: Int32, size: Int) = (0, 0)
        var next: Int32 = 1
        for start in 0..<(w * h) where mask.isFrame[start] && label[start] == 0 {
            var stack = [start], size = 0
            label[start] = next
            while let p = stack.popLast() {
                size += 1
                let x = p % w, y = p / w
                if x + 1 < w, mask.isFrame[p + 1], label[p + 1] == 0 { label[p + 1] = next; stack.append(p + 1) }
                if x > 0, mask.isFrame[p - 1], label[p - 1] == 0 { label[p - 1] = next; stack.append(p - 1) }
                if y + 1 < h, mask.isFrame[p + w], label[p + w] == 0 { label[p + w] = next; stack.append(p + w) }
                if y > 0, mask.isFrame[p - w], label[p - w] == 0 { label[p - w] = next; stack.append(p - w) }
            }
            if size > biggest.size { biggest = (next, size) }
            next += 1
        }
        return label.map { $0 == biggest.id && biggest.id != 0 }
    }

    func on(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < width && y < height && isFrame[y * width + x] }

    // A real hit is 3 frame pixels in a row, so one stray pixel can't stop a walk.
    private func solid(_ x: Int, _ y: Int, _ dx: Int, _ dy: Int) -> Bool {
        on(x, y) && on(x + dx, y + dy) && on(x + 2 * dx, y + 2 * dy)
    }

    // Moves an edge found in SAM's frame onto the strongest color change in the photo, within 5 px.
    // `edge` is the boundary between pixel edge-1 and pixel edge, across a row (alongX) or a column.
    private func snap(_ edge: Int, _ other: Int, alongX: Bool) -> Double {
        let best = (edge - 5...edge + 5).max { a, b in
            (alongX ? photo.jump(a - 1, other, a, other) : photo.jump(other, a - 1, other, a))
                < (alongX ? photo.jump(b - 1, other, b, other) : photo.jump(other, b - 1, other, b))
        } ?? edge
        return Double(best)
    }

    // A post's straight inside edge: row by row, walk from inside the opening outward to the first frame pixel.
    // Only the middle of the post is used, so the bends at the top and bottom can't pull the line.
    func postLine(top: CGPoint, bottom: CGPoint, outward: Int) -> Line? {
        guard bottom.y - top.y > 40 else { return nil }
        let y0 = Int(top.y + (bottom.y - top.y) * 0.15), y1 = Int(top.y + (bottom.y - top.y) * 0.85)
        let dots: [(t: Double, v: Double)] = (y0...y1).compactMap { y in
            let guess = top.x + (bottom.x - top.x) * (CGFloat(y) - top.y) / (bottom.y - top.y)
            var x = Int(guess) - outward * 30
            for _ in 0..<70 {
                if solid(x, y, outward, 0) { return (Double(y), snap(outward > 0 ? x : x + 1, y, alongX: true)) }
                x += outward
            }
            return nil
        }
        return fit(dots)
    }

    // The crossbar's straight inside edge: column by column, walk up from inside the opening to the first frame pixel.
    func crossbarLine(left: CGPoint, right: CGPoint) -> Line? {
        guard right.x - left.x > 40 else { return nil }
        let x0 = Int(left.x + (right.x - left.x) * 0.15), x1 = Int(left.x + (right.x - left.x) * 0.85)
        let dots: [(t: Double, v: Double)] = (x0...x1).compactMap { x in
            let guess = left.y + (right.y - left.y) * (CGFloat(x) - left.x) / (right.x - left.x)
            var y = Int(guess) + 30
            for _ in 0..<70 {
                if solid(x, y, 0, -1) { return (Double(x), snap(y + 1, x, alongX: false)) }
                y -= 1
            }
            return nil
        }
        return fit(dots)
    }

    // Where a post reaches the ice: the lowest frame pixel just outside the post's inside edge, near the tap.
    func ice(post: Line, near tap: CGPoint, outward: Int) -> CGPoint? {
        var lowest: Int? = nil
        for y in (Int(tap.y) - 40)...(Int(tap.y) + 40) {
            let x = Int(post.at(Double(y)))
            if (1...8).contains(where: { on(x + outward * $0, y) }) { lowest = y }
        }
        guard let lowest else { return nil }
        let y = Double(lowest + 1)
        return CGPoint(x: post.at(y), y: y)
    }

    // The rounded inside edge at a top corner, as a smooth arc of dots, or empty if the corner is sharp.
    // The bend's size comes from the photo: walk from the corner diagonally into the opening and see how far the
    // frame's color reaches before the netting starts. A bend of radius r reaches r·(√2 − 1) in along the diagonal.
    // `side` is 1 for the top-left (opening to the right) and -1 for the top-right.
    func bend(at corner: CGPoint, post: Line, bar: Line, side: Int) -> [CGPoint] {
        let down = unit(dx: post.b, dy: 1), along = unit(dx: Double(side), dy: bar.b * Double(side))
        let diagonal = unit(dx: down.dx + along.dx, dy: down.dy + along.dy)

        // The frame's own color right at this corner, a few pixels outside each inside edge.
        var samples: [(Int, Int, Int)] = []
        for k in 8...20 {
            let py = Double(corner.y) + Double(k), px = post.at(py) - Double(side) * 3
            if let c = photo.color(Int(px.rounded()), Int(py)) { samples.append(c) }
            let bx = Double(corner.x) + Double(side * k), by = bar.at(bx) - 3
            if let c = photo.color(Int(bx), Int(by.rounded())) { samples.append(c) }
        }
        guard samples.count >= 5 else { return [] }
        let frameColor = (samples.map(\.0).sorted()[samples.count / 2], samples.map(\.1).sorted()[samples.count / 2], samples.map(\.2).sorted()[samples.count / 2])
        func isFrameColored(_ d: Double) -> Bool {
            let x = Int((Double(corner.x) + d * diagonal.dx).rounded()), y = Int((Double(corner.y) + d * diagonal.dy).rounded())
            guard let c = photo.color(x, y) else { return false }
            return abs(c.0 - frameColor.0) + abs(c.1 - frameColor.1) + abs(c.2 - frameColor.2) <= 80
        }
        var reach = 0.0
        for d in stride(from: 0.0, through: 15.0, by: 0.5) {
            if isFrameColored(d) || isFrameColored(d + 0.5) || isFrameColored(d + 1) { reach = d } else { break }
        }
        let r = reach * (2.0.squareRoot() + 1)
        guard r >= 2 else { return [] }

        let cx = Double(corner.x) + r * (down.dx + along.dx), cy = Double(corner.y) + r * (down.dy + along.dy)
        let arc = stride(from: 0.0, through: 90.0, by: 3.0).map { $0 * .pi / 180 }.map { a in
            CGPoint(x: cx - r * (cos(a) * along.dx + sin(a) * down.dx), y: cy - r * (cos(a) * along.dy + sin(a) * down.dy))
        }
        // Top-left runs post side to crossbar side; top-right runs crossbar side to post side.
        return side > 0 ? arc : arc.reversed()
    }

    private func unit(dx: Double, dy: Double) -> (dx: Double, dy: Double) {
        let n = (dx * dx + dy * dy).squareRoot()
        return (dx / n, dy / n)
    }

    // Least-squares line through the dots, dropping strays a few times over.
    private func fit(_ dots: [(t: Double, v: Double)]) -> Line? {
        var keep = dots
        var line: Line? = nil
        for _ in 0..<5 {
            guard keep.count >= 10 else { return line }
            let n = Double(keep.count)
            let mt = keep.map(\.t).reduce(0, +) / n, mv = keep.map(\.v).reduce(0, +) / n
            let stt = keep.map { ($0.t - mt) * ($0.t - mt) }.reduce(0, +)
            let stv = keep.map { ($0.t - mt) * ($0.v - mv) }.reduce(0, +)
            let b = stt > 0 ? stv / stt : 0
            let fitted = Line(a: mv - b * mt, b: b)
            line = fitted
            let gaps = keep.map { abs($0.v - fitted.at($0.t)) }.sorted()
            let cut = max(1.5, 2.5 * gaps[gaps.count / 2])
            let next = keep.filter { abs($0.v - fitted.at($0.t)) <= cut }
            if next.count == keep.count { break }
            keep = next
        }
        return line
    }
}

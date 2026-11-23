import CoreVideo

/*
This class's only job is: find the dark moving spots in each camera frame as it arrives, with TwoFramesBack's rules and
answers but less work per frame, so it can keep up while the phone films.

It keeps the search strip's darkness for the last 9 frames and answers for the middle one, 4 frames back. A pixel counts when
it's more than 30 levels darker than the frames around it, so anything sitting still cancels out.
*/
struct FastFramesBack {
    private static let framesKept = 9, framesEachSide = 4, framesToCompare = 2
    private static let minDarkening: Int16 = 30, minStrength: Int16 = 50
    private static let minSize = 20, maxSize = 1500, maxWidth = 100, maxHeight = 50

    let rows: Range<Int>, columns: Range<Int>
    let scale: Double  // how big the net looks next to Nov 16, as in TwoFramesBack
    private let size: Int
    private var ring: [UInt8]  // the strip's darkness for the last 9 frames
    private var darkening: [Int16]
    private var waiting: [Bool]
    private var darkened: [Int] = []
    private var times = [Double](repeating: 0, count: framesKept)
    private var framesSeen = 0

    init(rows: Range<Int>, columns: Range<Int>, scale: Double = 1) {
        self.scale = scale
        self.rows = rows
        self.columns = columns
        size = rows.count * columns.count
        ring = [UInt8](repeating: 0, count: size * Self.framesKept)
        darkening = [Int16](repeating: 0, count: size)
        waiting = [Bool](repeating: false, count: size)
    }

    func fits(_ frame: CVPixelBuffer) -> Bool {
        rows.lowerBound >= 0 && columns.lowerBound >= 0 && rows.upperBound <= CVPixelBufferGetHeight(frame)
            && columns.upperBound <= CVPixelBufferGetWidth(frame)
    }

    // The frame must be locked. Gives the spot frame for the frame 4 frames back, once 9 frames are in.
    mutating func add(_ frame: CVPixelBuffer, time: Double) -> SpotFrame? {
        guard fits(frame) else { return nil }
        if size > 0 {
            let start = framesSeen % Self.framesKept * size, rows = rows, columns = columns
            ring.withUnsafeMutableBufferPointer { Self.storeDarkness(frame, rows: rows, columns: columns, into: $0.baseAddress! + start) }
        }
        return finish(time)
    }

    // Same as add(frame), with the strip's darkness already made by storeDarkness.
    mutating func add(darkness: UnsafePointer<UInt8>, time: Double) -> SpotFrame? {
        if size > 0 {
            let start = framesSeen % Self.framesKept * size, count = size
            ring.withUnsafeMutableBufferPointer { ($0.baseAddress! + start).update(from: darkness, count: count) }
        }
        return finish(time)
    }

    // The strip's darkness (255 minus the bigger of red and green), row after row, from a locked red-green-blue (BGRA) or
    // 420 frame.
    static func storeDarkness(_ frame: CVPixelBuffer, rows: Range<Int>, columns: Range<Int>, into out: UnsafeMutablePointer<UInt8>) {
        let format = CVPixelBufferGetPixelFormatType(frame), width = columns.count, firstColumn = columns.lowerBound
        if format == kCVPixelFormatType_32BGRA {
            let pixels = CVPixelBufferGetBaseAddress(frame)!.assumingMemoryBound(to: UInt8.self)
            let rowLength = CVPixelBufferGetBytesPerRow(frame)
            for (y, row) in rows.enumerated() {
                let from = pixels + row * rowLength + firstColumn * 4, to = out + y * width
                for x in 0..<width {
                    to[x] = 255 - max(from[x * 4 + 1], from[x * 4 + 2])
                }
            }
            return
        }
        let table = format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange ? DarknessTable.fullRange : DarknessTable.videoRange
        let luma = CVPixelBufferGetBaseAddressOfPlane(frame, 0)!.assumingMemoryBound(to: UInt8.self)
        let chroma = CVPixelBufferGetBaseAddressOfPlane(frame, 1)!.assumingMemoryBound(to: UInt8.self)
        let lumaRow = CVPixelBufferGetBytesPerRowOfPlane(frame, 0), chromaRow = CVPixelBufferGetBytesPerRowOfPlane(frame, 1)
        for (y, row) in rows.enumerated() {
            let brightness = luma + row * lumaRow, colors = chroma + (row / 2) * chromaRow, to = out + y * width
            for x in 0..<width {
                let column = firstColumn + x, pair = column / 2 * 2
                to[x] = table.darkness(y: brightness[column], cb: colors[pair], cr: colors[pair + 1])
            }
        }
    }

    private mutating func finish(_ time: Double) -> SpotFrame? {
        times[framesSeen % Self.framesKept] = time
        framesSeen += 1
        guard framesSeen >= Self.framesKept else { return nil }

        let middle = (framesSeen - 1 - Self.framesEachSide) % Self.framesKept
        let changed = darken(middle)
        return SpotFrame(time: times[middle], spots: spots(), changed: changed)
    }

    // A pixel's darkening is the smaller of how much darker it is than the frame before and the frame after.
    private mutating func darken(_ middle: Int) -> Int {
        darkened.removeAll(keepingCapacity: true)
        guard size > 0 else { return 0 }
        let before = comparison(to: middle, step: -1), after = comparison(to: middle, step: 1)
        let count = size, limit = Self.minDarkening
        var found = darkened
        darkened = []
        ring.withUnsafeBufferPointer { ring in
            let now = ring.baseAddress! + middle * count
            let earlier = ring.baseAddress! + before * count, later = ring.baseAddress! + after * count
            darkening.withUnsafeMutableBufferPointer { darkening in
                for pixel in 0..<count {
                    let value = Int16(min(Int(now[pixel]) - Int(earlier[pixel]), Int(now[pixel]) - Int(later[pixel])))
                    darkening[pixel] = value
                    if value > limit { found.append(pixel) }
                }
            }
        }
        darkened = found
        return found.count
    }

    // Lights that flicker 120 times a second are compared at the same point in the flicker: one flicker away, else two.
    private func comparison(to middle: Int, step: Int) -> Int {
        for flickers in [1.0, 2.0] {
            for distance in 1...Self.framesEachSide {
                let frame = slot(middle + step * distance)
                if abs(abs(times[frame] - times[middle]) - flickers / 120) < 0.001 { return frame }
            }
        }
        return slot(middle + step * Self.framesToCompare)
    }

    private func slot(_ position: Int) -> Int {
        (position + Self.framesKept) % Self.framesKept
    }

    private mutating func spots() -> [Spot] {
        let width = columns.count, height = rows.count
        for pixel in darkened { waiting[pixel] = true }
        var found: [Spot] = []
        var stack: [Int] = [], pixels: [Int] = []
        for seed in darkened where waiting[seed] {
            stack.removeAll(keepingCapacity: true)
            pixels.removeAll(keepingCapacity: true)
            stack.append(seed)
            waiting[seed] = false
            while let pixel = stack.popLast() {
                pixels.append(pixel)
                let x = pixel % width, y = pixel / width
                for nextY in max(y - 1, 0)...min(y + 1, height - 1) {
                    for nextX in max(x - 1, 0)...min(x + 1, width - 1) where waiting[nextY * width + nextX] {
                        waiting[nextY * width + nextX] = false
                        stack.append(nextY * width + nextX)
                    }
                }
            }
            if let spot = puckSizedSpot(from: pixels) { found.append(spot) }
        }
        return found
    }

    private func puckSizedSpot(from pixels: [Int]) -> Spot? {
        let grow = max(1, scale), shrink = min(1, scale)
        let sizes = Int((Double(Self.minSize) * shrink * shrink).rounded())...Int((Double(Self.maxSize) * grow * grow).rounded())
        guard sizes.contains(pixels.count) else { return nil }
        let across = pixels.map { $0 % columns.count }, down = pixels.map { $0 / columns.count }
        guard Double(across.max()! - across.min()!) < Double(Self.maxWidth) * grow,
              Double(down.max()! - down.min()!) < Double(Self.maxHeight) * grow else { return nil }
        let strengths = pixels.map { darkening[$0] }
        guard strengths.sorted()[strengths.count * 9 / 10] >= Self.minStrength else { return nil }
        let total = strengths.reduce(0.0) { $0 + Double($1) }
        let x = zip(across, strengths).reduce(0.0) { $0 + Double($1.0) * Double($1.1) } / total
        let y = zip(down, strengths).reduce(0.0) { $0 + Double($1.0) * Double($1.1) } / total
        return Spot(x: x + Double(columns.lowerBound), y: y + Double(rows.lowerBound), size: pixels.count)
    }
}

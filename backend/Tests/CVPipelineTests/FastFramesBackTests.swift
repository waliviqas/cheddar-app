import CoreVideo
import Foundation
import Testing
@testable import CVPipeline

@Suite("FastFramesBack")
struct FastFramesBackTests {
    // Reading only the search strip

    @Test("a strip as wide as the picture finds the puck, and 1 pixel wider finds nothing")
    func stripWidth() throws {
        #expect(isAtPuck(try spotFrames(9, movingSquare(black), columns: 0..<320).first?.spots.first))
        #expect(try spotFrames(9, movingSquare(black), columns: 0..<321).isEmpty)
    }

    @Test("a strip with no height finds nothing")
    func emptyStrip() throws {
        #expect(try spotFrames(9, movingSquare(black), rows: 0..<0).flatMap(\.spots).isEmpty)
    }

    @Test("a puck outside the strip is not found")
    func outsideStrip() throws {
        #expect(try spotFrames(9, movingSquare(black), rows: 0..<20).flatMap(\.spots).isEmpty)
    }

    @Test("a smaller strip keeps the puck's place in the full picture")
    func smallerStrip() throws {
        let spots = try spotFrames(9, movingSquare(black), rows: 10..<64, columns: 40..<320).firstResult.spots

        #expect(spots.count == 1)
        #expect(isAtPuck(spots.first))
    }

    @Test("a puck touching the strip's edge is found")
    func touchingStripEdge() throws {
        let spots = try spotFrames(9, movingSquare(black), columns: 84..<320).firstResult.spots

        #expect(spots.count == 1)
        #expect(isAtPuck(spots.first))
    }

    // Reading darkness from a camera frame

    @Test("a red-green-blue frame stores each pixel's darkness: 235 for the puck, 85 for the ice")
    func storesBGRA() throws {
        let darkness = stored(try bgraFrame { x, y in isInSquare(x, y, left: 84) ? black : ice })

        #expect(darkness(90, 30) == 235)
        #expect(darkness(10, 10) == 85)
    }

    @Test("the camera's 420 frame stores the same darkness")
    func stores420() throws {
        let darkness = stored(try yuvFrame(fullRange: false) { x, y in isInSquare(x, y, left: 84) ? (33, 128, 128) : (162, 128, 128) })

        #expect(darkness(90, 30) == 235)
        #expect(darkness(10, 10) == 85)
    }

    @Test("the frame's own range decides how brightness 20 is read: 235 in full range, 250 in video range")
    func rangeComesFromFrame() throws {
        #expect(stored(try yuvFrame(fullRange: true) { _, _ in (20, 128, 128) })(10, 10) == 235)
        #expect(stored(try yuvFrame(fullRange: false) { _, _ in (20, 128, 128) })(10, 10) == 250)
    }

    @Test("a strip starting on an odd row still lines the colors up")
    func oddStartingRow() throws {
        let bluePuck: (Int) throws -> CVPixelBuffer = { index in
            try yuvFrame(fullRange: true) { x, y in isInSquare(x, y, left: 20 + 16 * index) ? (37, 245, 117) : (170, 128, 128) }
        }

        #expect(isAtPuck(try spotFrames(9, bluePuck, rows: 0..<64).first?.spots.first))
        #expect(isAtPuck(try spotFrames(9, bluePuck, rows: 1..<64).first?.spots.first))
    }

    // Waiting for 9 frames

    @Test("8 frames are not enough to report anything")
    func eightFrames() throws {
        #expect(try spotFrames(8, movingSquare(black)).isEmpty)
    }

    @Test("9 frames give one spot frame with the 5th frame's time")
    func nineFrames() throws {
        let results = try spotFrames(9, movingSquare(black))

        #expect(results.count == 1)
        #expect(results.first?.time == 4.0 / 240)
    }

    @Test("every frame after that adds one spot frame, in time order")
    func oneEachFrame() throws {
        #expect(try spotFrames(16, movingSquare(black)).map(\.time) == (4..<12).map { Double($0) / 240 })
    }

    // Spotting what got darker

    @Test("a puck changes only its own 144 pixels")
    func puckChangedPixels() throws {
        #expect(try spotFrames(9, movingSquare(black)).firstResult.changed == 144)
    }

    @Test("a frame that goes completely dark changes every pixel")
    func pictureGoesDark() throws {
        #expect(try spotFrames(9) { index in try bgraFrame { _, _ in index == 4 ? black : ice } }.firstResult.changed == 20_480)
    }

    @Test("30 levels darker doesn't count, 31 does")
    func darkeningLimit() throws {
        #expect(try spotFrames(9, movingSquare(level(140))).firstResult.changed == 0)
        #expect(try spotFrames(9, movingSquare(level(139))).firstResult.changed == 144)
    }

    @Test("flickering lights leave only the puck")
    func flickeringLights() throws {
        let results = try flickerResults(Array(0..<16))

        #expect(results.count == 8)
        #expect(results.allSatisfy(isOnlyThePuck))
    }

    @Test("flickering lights leave only the puck across a dropped frame")
    func flickerAcrossDroppedFrame() throws {
        let results = try flickerResults((0..<16).filter { $0 != 6 })

        #expect(results.count == 7)
        #expect(results.allSatisfy(isOnlyThePuck))
    }

    @Test("flickering lights leave only the puck across several dropped frames")
    func flickerAcrossSeveralDroppedFrames() throws {
        let results = try flickerResults((0..<18).filter { !(6...9).contains($0) })

        #expect(results.count == 6)
        #expect(results.allSatisfy(isOnlyThePuck))
    }

    @Test("flickering lights leave only the puck when frames drop on both sides")
    func flickerWithDropsOnBothSides() throws {
        let results = try flickerResults((0..<18).filter { ![6, 8].contains($0) })

        #expect(results.count == 8)
        #expect(results.allSatisfy(isOnlyThePuck))
    }

    @Test("flickering lights leave only the puck when the frames one flicker away are missing")
    func flickerWithOneFlickerAwayMissing() throws {
        let results = try flickerResults((0..<18).filter { ![5, 9].contains($0) })

        #expect(results.count == 8)
        #expect(results.allSatisfy(isOnlyThePuck))
    }

    // Keeping only puck-sized spots

    @Test("a black puck is found at its exact spot")
    func blackPuck() throws {
        let spots = try spotFrames(9, movingSquare(black)).firstResult.spots

        #expect(spots.count == 1)
        #expect(isAtPuck(spots.first))
    }

    @Test("a blue puck is found at its exact spot")
    func bluePuck() throws {
        let spots = try spotFrames(9, movingSquare(blue)).firstResult.spots

        #expect(spots.count == 1)
        #expect(isAtPuck(spots.first))
    }

    @Test("something lighter than the floor is not a puck")
    func lighterThanFloor() throws {
        #expect(try spotFrames(9, movingSquare(white)).flatMap(\.spots).isEmpty)
    }

    @Test("a dark object sitting still is not a puck")
    func sittingStill() throws {
        #expect(try spotFrames(9) { _ in try bgraFrame { x, y in isInSquare(x, y, left: 84) ? black : ice } }
            .flatMap(\.spots).isEmpty)
    }

    @Test("a spot of 19 pixels is too small, and 20 is found")
    func smallestSize() throws {
        #expect(try spotFrames(9, blockOfPixels(19, width: 5)).firstResult.spots.isEmpty)
        #expect(try spotFrames(9, blockOfPixels(20, width: 5)).firstResult.spots.map(\.size) == [20])
    }

    @Test("a spot of 1,500 pixels is found, and 1,501 is too big")
    func biggestSize() throws {
        #expect(try spotFrames(9, blockOfPixels(1500, width: 50)).firstResult.spots.map(\.size) == [1500])
        #expect(try spotFrames(9, blockOfPixels(1501, width: 50)).firstResult.spots.isEmpty)
    }

    @Test("a spot 100 pixels wide is found, and 101 is too long")
    func widestSpot() throws {
        #expect(try spotFrames(9, blockOfPixels(200, width: 100)).firstResult.spots.count == 1)
        #expect(try spotFrames(9, blockOfPixels(202, width: 101)).firstResult.spots.isEmpty)
    }

    @Test("a spot 50 pixels tall is found, and 51 is too tall")
    func tallestSpot() throws {
        #expect(try spotFrames(9, blockOfPixels(100, width: 2)).firstResult.spots.count == 1)
        #expect(try spotFrames(9, blockOfPixels(102, width: 2)).firstResult.spots.isEmpty)
    }

    @Test("a faint darkening is not a puck")
    func faintDarkening() throws {
        let result = try spotFrames(9, movingSquare(dimIce)).firstResult

        #expect(result.changed == 144)
        #expect(result.spots.isEmpty)
    }

    @Test("a spot 49 levels darker is not a puck, and 50 is")
    func strengthLimit() throws {
        #expect(try spotFrames(9, movingSquare(level(121))).firstResult.spots.isEmpty)
        #expect(try spotFrames(9, movingSquare(level(120))).firstResult.spots.count == 1)
    }

    @Test("pixels touching only at a corner are one spot")
    func touchingOnlyAtCorner() throws {
        let shape = middleFrameShape { x, y in
            ((100..<106).contains(x) && (10..<16).contains(y)) || ((106..<112).contains(x) && (16..<22).contains(y))
        }

        #expect(try spotFrames(9, shape).firstResult.spots.map(\.size) == [72])
    }

    @Test("the middle of a spot leans toward its darker side")
    func leansTowardDarkerSide() throws {
        let result = try spotFrames(9) { index in
            try bgraFrame { x, y in
                guard index == 4, (100..<112).contains(x), (26..<38).contains(y) else { return ice }
                return x < 106 ? black : gray
            }
        }.firstResult
        let spot = try #require(result.spots.first)

        #expect(result.spots.count == 1)
        #expect(abs(spot.x - 104.214) <= 0.001)
        #expect(abs(spot.y - 31.5) <= 0.001)
    }

    @Test("two dark things moving are two spots")
    func twoDarkThings() throws {
        let spots = try spotFrames(9) { index in
            try bgraFrame { x, y in
                let left = 20 + 16 * index
                return isInSquare(x, y, left: left) || ((left..<left + 12).contains(x) && (2..<14).contains(y)) ? black : ice
            }
        }.firstResult.spots

        #expect(spots.count == 2)
        #expect(spots.contains { isAtPuck($0) })
        #expect(spots.contains { abs($0.x - 89.5) <= 0.001 && abs($0.y - 7.5) <= 0.001 })
    }

    // Same answers as today's spotter

    @Test("a made-up clip with flicker, a puck, its shadow and a dropped frame gives exactly what TwoFramesBack gives")
    func matchesTwoFramesBack() throws {
        let slots = (0..<60).filter { $0 != 30 }
        let frames = try slots.map { slot in
            try bgraFrame { x, y in
                let left = 20 + 4 * slot
                if (left..<left + 12).contains(x) && (26..<38).contains(y) { return black }
                if (left..<left + 12).contains(x) && (40..<46).contains(y) { return gray }
                return slot % 2 == 0 ? ice : dimIce
            }
        }
        let times = slots.map { Double($0) / 240 }
        let fast = fastResults(frames, times)

        #expect(fast.count == 51)
        #expect(same(fast, twoResults(frames, times)))
    }

    @Test("your 9 Nov 16 clips give exactly what TwoFramesBack gives, frame for frame", .enabled(if: realVideosRequested))
    func nov16MatchesTwoFramesBack() async throws {
        let clips = try JSONDecoder().decode([TappedClip].self,
                                             from: Data(contentsOf: rinkClips.appendingPathComponent("1x-measured-nov16/net-corners.json")))
        #expect(clips.count == 9)
        for clip in clips {
            let pose = try #require(CameraPose(corners: clip.net.taps, lens: iPhone))
            let lane = ShotReader.lane(corners: clip.net.taps, pose: pose)
            var fast = FastFramesBack(rows: lane.rows, columns: lane.columns)
            var two = TwoFramesBack(rows: lane.rows, columns: lane.columns)
            var fastFrames: [SpotFrame] = []
            try await Clip.eachFrame(rinkClips.appendingPathComponent(clip.clip)) { buffer, time in
                two.add(buffer, time: time)
                if let frame = fast.add(buffer, time: time) { fastFrames.append(frame) }
            }

            #expect(!fastFrames.isEmpty, "\(clip.clip)")
            #expect(same(fastFrames, two.frames), "\(clip.clip)")
        }
    }

    // Handing in darkness directly

    @Test("darkness handed in directly gives the same spot frame as the camera frame")
    func darknessHandedIn() throws {
        var byFrame = FastFramesBack(rows: 0..<64, columns: 0..<320)
        var byDarkness = FastFramesBack(rows: 0..<64, columns: 0..<320)
        var fromFrame: SpotFrame?, fromDarkness: SpotFrame?
        for index in 0..<9 {
            let frame = try movingSquare(black)(index)
            var darkness = [UInt8](repeating: 0, count: 64 * 320)
            CVPixelBufferLockBaseAddress(frame, .readOnly)
            fromFrame = byFrame.add(frame, time: Double(index) / 240)
            darkness.withUnsafeMutableBufferPointer {
                FastFramesBack.storeDarkness(frame, rows: 0..<64, columns: 0..<320, into: $0.baseAddress!)
            }
            CVPixelBufferUnlockBaseAddress(frame, .readOnly)
            fromDarkness = darkness.withUnsafeBufferPointer { byDarkness.add(darkness: $0.baseAddress!, time: Double(index) / 240) }
        }

        #expect(same([try #require(fromFrame)], [try #require(fromDarkness)]))
    }
}

private extension Array where Element == SpotFrame {
    // The first spot frame, failing the test instead of crashing when there's none.
    var firstResult: SpotFrame {
        get throws { try #require(first) }
    }
}

private struct Color3 {
    let red: UInt8, green: UInt8, blue: UInt8
}

private func level(_ value: UInt8) -> Color3 { Color3(red: value, green: value, blue: value) }

private let ice = level(170), dimIce = level(130), gray = level(110), black = level(20), white = level(255)
private let blue = Color3(red: 20, green: 20, blue: 255)
private let iPhone = Lens(zoom: 1470.2, centerX: 960, centerY: 540)
private let realVideosRequested = ProcessInfo.processInfo.environment["CHEDDAR_REAL_VIDEOS"] == "1"
private let rinkClips = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("videos/rink-clips")

private struct TappedClip: Decodable {
    struct Point: Decodable { let x: Double, y: Double }
    struct Net: Decodable {
        let leftTop: Point, rightTop: Point, rightBottom: Point, leftBottom: Point
        var taps: [Vec2] { [leftTop, rightTop, rightBottom, leftBottom].map { Vec2($0.x, $0.y) } }
    }
    let clip: String
    let net: Net
}

private func spotFrames(_ count: Int, _ draw: (Int) throws -> CVPixelBuffer,
                        rows: Range<Int> = 0..<64, columns: Range<Int> = 0..<320) throws -> [SpotFrame] {
    var finder = FastFramesBack(rows: rows, columns: columns)
    var results: [SpotFrame] = []
    for index in 0..<count {
        let frame = try draw(index)
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        if let result = finder.add(frame, time: Double(index) / 240) { results.append(result) }
        CVPixelBufferUnlockBaseAddress(frame, .readOnly)
    }
    return results
}

private func flickerResults(_ slots: [Int]) throws -> [SpotFrame] {
    let frames = try slots.map { slot in
        try bgraFrame { x, y in isInSquare(x, y, left: 20 + 16 * slot) ? black : (slot % 2 == 0 ? ice : dimIce) }
    }
    return fastResults(frames, slots.map { Double($0) / 240 })
}

private func fastResults(_ frames: [CVPixelBuffer], _ times: [Double]) -> [SpotFrame] {
    var finder = FastFramesBack(rows: 0..<64, columns: 0..<320)
    var results: [SpotFrame] = []
    for (frame, time) in zip(frames, times) {
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        if let result = finder.add(frame, time: time) { results.append(result) }
        CVPixelBufferUnlockBaseAddress(frame, .readOnly)
    }
    return results
}

private func twoResults(_ frames: [CVPixelBuffer], _ times: [Double]) -> [SpotFrame] {
    var finder = TwoFramesBack(rows: 0..<64, columns: 0..<320)
    for (frame, time) in zip(frames, times) {
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        finder.add(frame, time: time)
        CVPixelBufferUnlockBaseAddress(frame, .readOnly)
    }
    return finder.frames
}

private func same(_ a: [SpotFrame], _ b: [SpotFrame]) -> Bool {
    a.count == b.count && zip(a, b).allSatisfy { one, other in
        one.time == other.time && one.changed == other.changed && one.spots.count == other.spots.count
            && zip(one.spots, other.spots).allSatisfy { abs($0.x - $1.x) < 1e-9 && abs($0.y - $1.y) < 1e-9 && $0.size == $1.size }
    }
}

private func isOnlyThePuck(_ result: SpotFrame) -> Bool {
    guard result.spots.count == 1 else { return false }
    let slot = (result.time * 240).rounded()
    return abs(result.spots[0].x - (25.5 + 16 * slot)) <= 0.001 && abs(result.spots[0].y - 31.5) <= 0.001
}

private func movingSquare(_ color: Color3) -> (Int) throws -> CVPixelBuffer {
    { index in try bgraFrame { x, y in isInSquare(x, y, left: 20 + 16 * index) ? color : ice } }
}

private func middleFrameShape(_ isInShape: @escaping (Int, Int) -> Bool) -> (Int) throws -> CVPixelBuffer {
    { index in try bgraFrame { x, y in index == 4 && isInShape(x, y) ? black : ice } }
}

private func blockOfPixels(_ count: Int, width: Int) -> (Int) throws -> CVPixelBuffer {
    middleFrameShape { x, y in
        (100..<100 + width).contains(x) && y >= 10 && (y - 10) * width + (x - 100) < count
    }
}

private func isInSquare(_ x: Int, _ y: Int, left: Int) -> Bool {
    (left..<left + 12).contains(x) && (26..<38).contains(y)
}

private func isAtPuck(_ spot: Spot?) -> Bool {
    guard let spot else { return false }
    return abs(spot.x - 89.5) <= 0.001 && abs(spot.y - 31.5) <= 0.001
}

// What FastFramesBack stores for a 320×64 frame: one darkness number for each pixel, row after row.
private func stored(_ frame: CVPixelBuffer) -> (Int, Int) -> UInt8 {
    var darkness = [UInt8](repeating: 0, count: 64 * 320)
    CVPixelBufferLockBaseAddress(frame, .readOnly)
    darkness.withUnsafeMutableBufferPointer { FastFramesBack.storeDarkness(frame, rows: 0..<64, columns: 0..<320, into: $0.baseAddress!) }
    CVPixelBufferUnlockBaseAddress(frame, .readOnly)
    let result = darkness
    return { x, y in result[y * 320 + x] }
}

private func bgraFrame(_ paint: (Int, Int) -> Color3) throws -> CVPixelBuffer {
    var made: CVPixelBuffer?
    CVPixelBufferCreate(nil, 320, 64, kCVPixelFormatType_32BGRA, nil, &made)
    let frame = try #require(made)
    CVPixelBufferLockBaseAddress(frame, [])
    defer { CVPixelBufferUnlockBaseAddress(frame, []) }
    let pixels = CVPixelBufferGetBaseAddress(frame)!.assumingMemoryBound(to: UInt8.self)
    let rowLength = CVPixelBufferGetBytesPerRow(frame)
    for y in 0..<64 {
        for x in 0..<320 {
            let color = paint(x, y), at = y * rowLength + x * 4
            pixels[at] = color.blue
            pixels[at + 1] = color.green
            pixels[at + 2] = color.red
            pixels[at + 3] = 255
        }
    }
    return frame
}

// A 320×64 frame in the camera's 420 format: brightness for every pixel, one color pair for each 2×2 block (taken from its
// top-left pixel).
private func yuvFrame(fullRange: Bool, _ paint: (Int, Int) -> (UInt8, UInt8, UInt8)) throws -> CVPixelBuffer {
    var made: CVPixelBuffer?
    let format = fullRange ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    CVPixelBufferCreate(nil, 320, 64, format, nil, &made)
    let frame = try #require(made)
    CVPixelBufferLockBaseAddress(frame, [])
    defer { CVPixelBufferUnlockBaseAddress(frame, []) }
    let luma = CVPixelBufferGetBaseAddressOfPlane(frame, 0)!.assumingMemoryBound(to: UInt8.self)
    let chroma = CVPixelBufferGetBaseAddressOfPlane(frame, 1)!.assumingMemoryBound(to: UInt8.self)
    let lumaRow = CVPixelBufferGetBytesPerRowOfPlane(frame, 0), chromaRow = CVPixelBufferGetBytesPerRowOfPlane(frame, 1)
    for y in 0..<64 {
        for x in 0..<320 {
            let (brightness, cb, cr) = paint(x, y)
            luma[y * lumaRow + x] = brightness
            if x % 2 == 0 && y % 2 == 0 {
                chroma[(y / 2) * chromaRow + x] = cb
                chroma[(y / 2) * chromaRow + x + 1] = cr
            }
        }
    }
    return frame
}

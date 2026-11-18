import CoreVideo
import Testing
@testable import CVPipeline

@Suite("TwoFramesBack")
struct TwoFramesBackTests {
    @Test("8 frames are not enough to report anything")
    func tooFewFrames() throws {
        #expect(try spotFrames(8, movingSquare(black)).isEmpty)
    }

    @Test("9 frames give one result with the 5th frame's time")
    func firstResult() throws {
        let results = try spotFrames(9, movingSquare(black))

        #expect(results.count == 1)
        #expect(abs(results[0].time - 4.0 / 240) <= 1e-9)
    }

    @Test("every frame after that adds one result in a row")
    func oneResultPerFrame() throws {
        let results = try spotFrames(16, movingSquare(black))

        #expect(results.count == 8)
        for (index, result) in results.enumerated() {
            #expect(abs(result.time - Double(index + 4) / 240) <= 1e-9)
        }
    }

    @Test("a black puck is found at its exact spot")
    func blackPuck() throws {
        let spots = try spotFrames(9, movingSquare(black))[0].spots

        #expect(spots.count == 1)
        #expect(isAtPuck(spots.first))
    }

    @Test("a blue puck is found at its exact spot")
    func bluePuck() throws {
        let spots = try spotFrames(9, movingSquare(blue))[0].spots

        #expect(spots.count == 1)
        #expect(isAtPuck(spots.first))
    }

    @Test("something lighter than the floor is not a puck")
    func lighterThanFloor() throws {
        #expect(try spotFrames(9, movingSquare(white)).flatMap(\.spots).isEmpty)
    }

    @Test("a dark object sitting still is not a puck")
    func sittingStill() throws {
        #expect(try spotFrames(9, stillSquare(black)).flatMap(\.spots).isEmpty)
    }

    @Test("a puck outside the search area is not found")
    func outsideSearchArea() throws {
        #expect(try spotFrames(9, movingSquare(black), rows: 0..<20).flatMap(\.spots).isEmpty)
    }

    @Test("a smaller search area keeps the puck's position in the full picture")
    func smallerSearchArea() throws {
        let spots = try spotFrames(9, movingSquare(black), rows: 10..<64, columns: 40..<320)[0].spots

        #expect(spots.count == 1)
        #expect(isAtPuck(spots.first))
    }

    @Test("a search area wider than the video finds nothing")
    func searchAreaTooWide() throws {
        #expect(try spotFrames(9, movingSquare(black), columns: 0..<400).flatMap(\.spots).isEmpty)
    }

    @Test("a search area with no height finds nothing")
    func emptySearchArea() throws {
        #expect(try spotFrames(9, movingSquare(black), rows: 0..<0).flatMap(\.spots).isEmpty)
    }

    @Test("a normal puck changes only its own pixels")
    func puckChangedPixels() throws {
        #expect(try spotFrames(9, movingSquare(black))[0].changed == 144)
    }

    @Test("a frame that goes completely dark changes every pixel")
    func wholePictureDarkens() throws {
        let results = try spotFrames(9) { index in
            try makeFrame { _, _ in index == 4 ? black : ice }
        }

        #expect(results[0].changed == 20_480)
    }

    @Test("flickering lights leave only the puck")
    func flickeringLights() throws {
        let slots = Array(0..<16)

        let results = try flickerResults(slots)

        #expect(results.count == slots.count - 8)
        #expect(results.allSatisfy(isOnlyThePuck))
    }

    @Test("flickering lights leave only the puck across a dropped frame")
    func flickerAcrossDroppedFrame() throws {
        let slots = (0..<16).filter { $0 != 6 }

        let results = try flickerResults(slots)

        #expect(results.count == slots.count - 8)
        #expect(results.allSatisfy(isOnlyThePuck))
    }

    @Test("flickering lights leave only the puck across several dropped frames")
    func flickerAcrossSeveralDroppedFrames() throws {
        let slots = (0..<18).filter { !(6...9).contains($0) }

        let results = try flickerResults(slots)

        #expect(results.count == slots.count - 8)
        #expect(results.allSatisfy(isOnlyThePuck))
    }

    @Test("flickering lights leave only the puck when frames drop on both sides")
    func flickerWithDropsOnBothSides() throws {
        let slots = (0..<18).filter { ![6, 8].contains($0) }

        let results = try flickerResults(slots)

        #expect(results.count == slots.count - 8)
        #expect(results.allSatisfy(isOnlyThePuck))
    }

    @Test("flickering lights leave only the puck when the frames one flicker away are missing")
    func flickerWithOneFlickerAwayMissing() throws {
        let slots = (0..<18).filter { ![5, 9].contains($0) }

        let results = try flickerResults(slots)

        #expect(results.count == slots.count - 8)
        #expect(results.allSatisfy(isOnlyThePuck))
    }

    @Test("two dark things moving are two spots")
    func twoDarkThings() throws {
        let results = try spotFrames(9) { index in
            try makeFrame { x, y in
                let left = 20 + 16 * index
                let isSecondThing = (left..<left + 12).contains(x) && (2..<14).contains(y)
                return isInSquare(x, y, left: left) || isSecondThing ? black : ice
            }
        }

        #expect(results[0].spots.count == 2)
        #expect(results[0].spots.contains { isAtPuck($0) })
        #expect(results[0].spots.contains { abs($0.x - 89.5) <= 0.001 && abs($0.y - 7.5) <= 0.001 })
    }

    @Test("a spot of 19 pixels is too small to be a puck")
    func tooSmall() throws {
        #expect(try spotFrames(9, blockOfPixels(19, width: 5))[0].spots.isEmpty)
    }

    @Test("a spot of 20 pixels is found")
    func smallestSpot() throws {
        let spots = try spotFrames(9, blockOfPixels(20, width: 5))[0].spots

        #expect(spots.count == 1)
        #expect(spots.first?.size == 20)
    }

    @Test("a spot of 1,500 pixels is found")
    func biggestSpot() throws {
        let spots = try spotFrames(9, blockOfPixels(1500, width: 50))[0].spots

        #expect(spots.count == 1)
        #expect(spots.first?.size == 1500)
    }

    @Test("a spot of 1,501 pixels is too big to be a puck")
    func tooBig() throws {
        #expect(try spotFrames(9, blockOfPixels(1501, width: 50))[0].spots.isEmpty)
    }

    @Test("a spot 101 pixels wide is too long to be a puck")
    func tooWide() throws {
        #expect(try spotFrames(9, blockOfPixels(202, width: 101))[0].spots.isEmpty)
    }

    @Test("a spot 51 pixels tall is too tall to be a puck")
    func tooTall() throws {
        #expect(try spotFrames(9, blockOfPixels(102, width: 2))[0].spots.isEmpty)
    }

    @Test("a faint darkening is not a puck")
    func faintDarkening() throws {
        let result = try spotFrames(9, movingSquare(dimIce))[0]

        #expect(result.changed == 144)
        #expect(result.spots.isEmpty)
    }

    @Test("pixels touching only at a corner are one spot")
    func touchingOnlyAtCorner() throws {
        let shape = middleFrameShape { x, y in
            ((100..<106).contains(x) && (10..<16).contains(y)) || ((106..<112).contains(x) && (16..<22).contains(y))
        }

        let spots = try spotFrames(9, shape)[0].spots

        #expect(spots.count == 1)
        #expect(spots.first?.size == 72)
    }

    @Test("the middle of a spot leans toward its darker side")
    func leansTowardDarkerSide() throws {
        let results = try spotFrames(9) { index in
            try makeFrame { x, y in
                guard index == 4, (100..<112).contains(x), (26..<38).contains(y) else { return ice }
                return x < 106 ? black : gray
            }
        }
        let spot = try #require(results[0].spots.first)

        #expect(results[0].spots.count == 1)
        #expect(abs(spot.x - 104.214) <= 0.001)
        #expect(abs(spot.y - 31.5) <= 0.001)
    }

    @Test("a puck touching the edge of the search area is found")
    func touchingSearchAreaEdge() throws {
        let spots = try spotFrames(9, movingSquare(black), columns: 84..<320)[0].spots

        #expect(spots.count == 1)
        #expect(isAtPuck(spots.first))
    }
}

private struct Pixel {
    let blue: UInt8, green: UInt8, red: UInt8
}

private let ice = Pixel(blue: 170, green: 170, red: 170)
private let dimIce = Pixel(blue: 130, green: 130, red: 130)
private let gray = Pixel(blue: 110, green: 110, red: 110)
private let black = Pixel(blue: 20, green: 20, red: 20)
private let blue = Pixel(blue: 255, green: 20, red: 20)
private let white = Pixel(blue: 255, green: 255, red: 255)

private func spotFrames(_ count: Int, _ draw: (Int) throws -> CVPixelBuffer,
                        rows: Range<Int> = 0..<64, columns: Range<Int> = 0..<320) throws -> [SpotFrame] {
    var finder = TwoFramesBack(rows: rows, columns: columns)
    for index in 0..<count {
        let frame = try draw(index)
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        finder.add(frame, time: Double(index) / 240)
        CVPixelBufferUnlockBaseAddress(frame, .readOnly)
    }
    return finder.frames
}

private func flickerResults(_ slots: [Int]) throws -> [SpotFrame] {
    var finder = TwoFramesBack(rows: 0..<64, columns: 0..<320)
    for slot in slots {
        let frame = try makeFrame { x, y in
            isInSquare(x, y, left: 20 + 16 * slot) ? black : (slot % 2 == 0 ? ice : dimIce)
        }
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        finder.add(frame, time: Double(slot) / 240)
        CVPixelBufferUnlockBaseAddress(frame, .readOnly)
    }
    return finder.frames
}

private func isOnlyThePuck(_ result: SpotFrame) -> Bool {
    guard result.spots.count == 1 else { return false }
    let slot = (result.time * 240).rounded()
    return abs(result.spots[0].x - (25.5 + 16 * slot)) <= 0.001 && abs(result.spots[0].y - 31.5) <= 0.001
}

private func movingSquare(_ color: Pixel) -> (Int) throws -> CVPixelBuffer {
    { index in try makeFrame { x, y in isInSquare(x, y, left: 20 + 16 * index) ? color : ice } }
}

private func stillSquare(_ color: Pixel) -> (Int) throws -> CVPixelBuffer {
    { _ in try makeFrame { x, y in isInSquare(x, y, left: 84) ? color : ice } }
}

private func middleFrameShape(_ isInShape: @escaping (Int, Int) -> Bool) -> (Int) throws -> CVPixelBuffer {
    { index in try makeFrame { x, y in index == 4 && isInShape(x, y) ? black : ice } }
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

private func makeFrame(_ paint: (Int, Int) -> Pixel) throws -> CVPixelBuffer {
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

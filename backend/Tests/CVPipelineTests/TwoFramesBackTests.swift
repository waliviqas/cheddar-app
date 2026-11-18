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
}

private struct Pixel {
    let blue: UInt8, green: UInt8, red: UInt8
}

private let ice = Pixel(blue: 170, green: 170, red: 170)
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

private func movingSquare(_ color: Pixel) -> (Int) throws -> CVPixelBuffer {
    { index in try makeFrame { x, y in isInSquare(x, y, left: 20 + 16 * index) ? color : ice } }
}

private func stillSquare(_ color: Pixel) -> (Int) throws -> CVPixelBuffer {
    { _ in try makeFrame { x, y in isInSquare(x, y, left: 84) ? color : ice } }
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

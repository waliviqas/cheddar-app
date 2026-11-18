import Testing
@testable import CVPipeline

@Suite("NetCorners")
struct NetCornersTests {
    @Test("an upright post and a level bar meet at the corner")
    func uprightPostAndLevelBar() {
        let corner = NetCorners.meet(post: .init(a: 100, b: 0), bar: .init(a: 50, b: 0))

        #expect(isClose(corner, to: Vec2(100, 50), within: 1e-9))
    }

    @Test("a leaning post and a sloped bar meet at the corner")
    func leaningPostAndSlopedBar() {
        let corner = NetCorners.meet(post: .init(a: 100, b: 0.1), bar: .init(a: 50, b: 0.2))

        #expect(isClose(corner, to: Vec2(107.143, 71.429), within: 0.001))
    }

    @Test("a clean edge gives the exact line")
    func cleanEdge() {
        #expect(isTrueLine(NetCorners.robustLine(edgePoints(20)), within: 1e-6))
    }

    @Test("half-pixel wobble averages out")
    func halfPixelWobble() {
        let everyRow = edgePoints(20, wobble: 0.5)
        let someRows = edgePoints(12, bad: [1: 0.5, 3: -0.5, 5: 0.5, 7: -0.5, 9: 0.5])

        #expect(isTrueLine(NetCorners.robustLine(everyRow), within: 0.1))
        #expect(isTrueLine(NetCorners.robustLine(someRows), within: 0.5))
    }

    @Test("a few bad rows are ignored")
    func fewBadRows() {
        #expect(isTrueLine(NetCorners.robustLine(edgePoints(30, bad: [10: 20, 15: 20, 20: 20])), within: 1e-6))
    }

    @Test("9 points are too few for a line")
    func ninePoints() {
        #expect(NetCorners.robustLine(edgePoints(9)) == nil)
    }

    @Test("10 points are enough for a line")
    func tenPoints() {
        #expect(isTrueLine(NetCorners.robustLine(edgePoints(10)), within: 1e-6))
    }

    @Test("9 good points and 1 bad point are too few for a line")
    func nineGoodOneBad() {
        #expect(NetCorners.robustLine(edgePoints(10, bad: [5: 20])) == nil)
    }

    @Test("red at the expected spot is found")
    func redAtExpectedSpot() {
        #expect(isRun(findRed(100...110, expectedAt: 105, postHeight: 300), 100, 110))
    }

    @Test("the closest of two red stretches is picked")
    func closestRedStretch() {
        #expect(isRun(findRed(80...90, 100...110, expectedAt: 102, postHeight: 300), 100, 110))
    }

    @Test("red 5 pixels wide on a 300-pixel post is found")
    func fiveWide() {
        #expect(isRun(findRed(100...104, expectedAt: 102, postHeight: 300), 100, 104))
    }

    @Test("red 4 pixels wide on a 300-pixel post is too thin")
    func fourWide() {
        #expect(findRed(100...103, expectedAt: 101, postHeight: 300) == nil)
    }

    @Test("red 33 pixels wide on a 300-pixel post is found")
    func thirtyThreeWide() {
        #expect(isRun(findRed(84...116, expectedAt: 100, postHeight: 300), 84, 116))
    }

    @Test("red 34 pixels wide on a 300-pixel post is too wide")
    func thirtyFourWide() {
        #expect(findRed(84...117, expectedAt: 100, postHeight: 300) == nil)
    }

    @Test("red starting 30 pixels away on a 300-pixel post is found")
    func thirtyAway() {
        #expect(isRun(findRed(130...140, expectedAt: 100, postHeight: 300), 130, 140))
    }

    @Test("red starting 31 pixels away on a 300-pixel post is too far")
    func thirtyOneAway() {
        #expect(findRed(131...141, expectedAt: 100, postHeight: 300) == nil)
    }

    @Test("red 8 pixels wide on a 600-pixel post is too thin")
    func eightWideUpClose() {
        #expect(findRed(100...107, expectedAt: 103, postHeight: 600) == nil)
    }

    @Test("red 9 pixels wide on a 600-pixel post is found")
    func nineWideUpClose() {
        #expect(isRun(findRed(100...108, expectedAt: 104, postHeight: 600), 100, 108))
    }

    @Test("red 66 pixels wide on a 600-pixel post is found")
    func sixtySixWideUpClose() {
        #expect(isRun(findRed(67...132, expectedAt: 100, postHeight: 600), 67, 132))
    }

    @Test("red 67 pixels wide on a 600-pixel post is too wide")
    func sixtySevenWideUpClose() {
        #expect(findRed(67...133, expectedAt: 100, postHeight: 600) == nil)
    }

    @Test("red starting 60 pixels away on a 600-pixel post is found")
    func sixtyAwayUpClose() {
        #expect(isRun(findRed(160...170, expectedAt: 100, postHeight: 600), 160, 170))
    }

    @Test("red starting 61 pixels away on a 600-pixel post is too far")
    func sixtyOneAwayUpClose() {
        #expect(findRed(161...171, expectedAt: 100, postHeight: 600) == nil)
    }

    @Test("a sunlit red post counts")
    func sunlitRed() {
        #expect(isCounted(Paint(180, 40, 40)))
    }

    @Test("a shaded red post counts")
    func shadedRed() {
        #expect(isCounted(Paint(90, 60, 100)))
    }

    @Test("brightness 29 counts as a dark frame")
    func brightness29() {
        #expect(isCounted(Paint(29, 29, 29)))
    }

    @Test("brightness 30 is not a dark frame")
    func brightness30() {
        #expect(!isCounted(Paint(30, 30, 30)))
    }

    @Test("red at brightness 149 counts")
    func redBrightness149() {
        #expect(isCounted(Paint(220, 100, 127)))
    }

    @Test("red at brightness 150 is too bright")
    func redBrightness150() {
        #expect(!isCounted(Paint(220, 100, 130)))
    }

    @Test("green 10 below the red-blue average counts")
    func greenTenBelow() {
        #expect(isCounted(Paint(100, 90, 100)))
    }

    @Test("green 9 below the red-blue average does not count")
    func greenNineBelow() {
        #expect(!isCounted(Paint(100, 91, 100)))
    }

    @Test("red 8 above green counts")
    func redEightAboveGreen() {
        #expect(isCounted(Paint(100, 92, 120)))
    }

    @Test("red 7 above green does not count")
    func redSevenAboveGreen() {
        #expect(!isCounted(Paint(100, 93, 120)))
    }

    @Test("a blue tarp does not count")
    func blueTarp() {
        #expect(!isCounted(Paint(40, 80, 200)))
    }

    @Test("green grass does not count")
    func greenGrass() {
        #expect(!isCounted(Paint(60, 140, 50)))
    }

    @Test("white ice does not count")
    func whiteIce() {
        #expect(!isCounted(Paint(230, 230, 230)))
    }

    @Test("red 60 pixels left of the taps on a 300-pixel post is searched")
    func searchReaches60() {
        #expect(allRedMask(postHeight: 300).at(140, 200))
    }

    @Test("red 61 pixels left of the taps on a 300-pixel post is not searched")
    func searchStopsBefore61() {
        #expect(!allRedMask(postHeight: 300).at(139, 200))
    }

    @Test("red 120 pixels left of the taps on a 600-pixel post is searched")
    func searchReaches120() {
        #expect(allRedMask(postHeight: 600).at(80, 200))
    }

    @Test("red 121 pixels left of the taps on a 600-pixel post is not searched")
    func searchStopsBefore121() {
        #expect(!allRedMask(postHeight: 600).at(79, 200))
    }

    @Test("taps at the edge of the picture are searched without a crash")
    func tapsAtPictureEdge() {
        let picture = paintedPicture(640, 480) { _, _ in frameRed }
        let taps = [Vec2(5, 5), Vec2(300, 5), Vec2(300, 305), Vec2(5, 305)]

        #expect(NetCorners.postMask(picture, around: taps).at(0, 0))
    }

    @Test("a straight post gives its exact edges")
    func straightPost() {
        let post = mask { x, _ in inPost(x) }

        #expect(hasPostEdges(NetCorners.postEdges(post, top: postTop, bottom: postBottom)))
    }

    @Test("a leaning post gives leaning edges")
    func leaningPost() throws {
        let post = mask { x, y in
            let lean = 0.1 * Double(y - 50)
            let isDecoy = y >= 200 && (100..<110).contains(x)
            return isDecoy || (Double(x) >= 99.5 + lean && Double(x) <= 119.5 + lean)
        }

        let edges = try #require(NetCorners.postEdges(post, top: postTop, bottom: Vec2(140, 350)))

        #expect(abs(edges.left.b - 0.1) <= 0.005)
        #expect(abs(edges.right.b - 0.1) <= 0.005)
        #expect(abs(edges.left.at(50) - 99.5) <= 0.1)
        #expect(abs(edges.right.at(50) - 119.5) <= 0.1)
    }

    @Test("the rounded corner rows of a 300-pixel post are skipped")
    func cornerRowsSkipped() {
        let post = mask { x, y in inPost(x) && ((50..<74).contains(y) || (327...350).contains(y)) }

        #expect(NetCorners.postEdges(post, top: postTop, bottom: postBottom) == nil)
    }

    @Test("the rounded corner rows of a 600-pixel post are skipped")
    func cornerRowsSkippedUpClose() {
        let post = mask { x, y in inPost(x) && ((50..<98).contains(y) || (603...650).contains(y)) }

        #expect(NetCorners.postEdges(post, top: postTop, bottom: tallPostBottom) == nil)
    }

    @Test("netting on a few rows doesn't move the edges")
    func nettingOnFewRows() {
        let post = mask { x, y in (200..<205).contains(y) ? (100..<130).contains(x) : inPost(x) }

        #expect(hasPostEdges(NetCorners.postEdges(post, top: postTop, bottom: postBottom)))
    }

    @Test("30 hidden rows don't move the edges")
    func thirtyHiddenRows() {
        let post = mask { x, y in !(200..<230).contains(y) && inPost(x) }

        #expect(hasPostEdges(NetCorners.postEdges(post, top: postTop, bottom: postBottom)))
    }

    @Test("no post gives no edges")
    func noPost() {
        #expect(NetCorners.postEdges(mask { _, _ in false }, top: postTop, bottom: postBottom) == nil)
    }

    @Test("9 visible rows are too few for edges")
    func nineVisibleRows() {
        let post = mask { x, y in inPost(x) && (74..<83).contains(y) }

        #expect(NetCorners.postEdges(post, top: postTop, bottom: postBottom) == nil)
    }

    @Test("10 visible rows are enough for edges")
    func tenVisibleRows() {
        let post = mask { x, y in inPost(x) && (74..<84).contains(y) }

        #expect(hasPostEdges(NetCorners.postEdges(post, top: postTop, bottom: postBottom)))
    }

    @Test("10 visible rows on a 600-pixel post are enough for edges")
    func tenVisibleRowsUpClose() {
        let post = mask { x, y in inPost(x) && (98..<108).contains(y) }

        #expect(hasPostEdges(NetCorners.postEdges(post, top: postTop, bottom: tallPostBottom)))
    }

    @Test("top and bottom taps on the same spot give no edges")
    func postTapsOnSameSpot() {
        let spot = Vec2(110, 100)

        #expect(NetCorners.postEdges(mask { x, _ in inPost(x) }, top: spot, bottom: spot) == nil)
    }

    @Test("a level bar gives its exact lower edge")
    func levelBar() {
        let bar = mask(width: 1000, height: 300) { _, y in inBar(y) }

        #expect(isBarEdge(NetCorners.barBottom(bar, left: barLeft, right: barRight, postHeight: 300)))
    }

    @Test("a sloped bar gives a sloped lower edge")
    func slopedBar() throws {
        let bar = mask(width: 1000, height: 300) { x, y in
            let slope = 0.1 * Double(x - 100)
            let isDecoy = x >= 300 && (100..<110).contains(y)
            return isDecoy || (Double(y) >= 99.5 + slope && Double(y) <= 114.5 + slope)
        }

        let edge = try #require(NetCorners.barBottom(bar, left: barLeft, right: Vec2(500, 147), postHeight: 300))

        #expect(abs(edge.b - 0.1) <= 0.005)
        #expect(abs(edge.at(100) - 114.5) <= 0.1)
    }

    @Test("the rounded corner columns of a 400-pixel bar are skipped")
    func cornerColumnsSkipped() {
        let bar = mask(width: 1000, height: 300) { x, y in
            inBar(y) && ((100..<148).contains(x) || (453...500).contains(x))
        }

        #expect(NetCorners.barBottom(bar, left: barLeft, right: barRight, postHeight: 300) == nil)
    }

    @Test("the rounded corner columns of an 800-pixel bar are skipped")
    func cornerColumnsSkippedUpClose() {
        let bar = mask(width: 1000, height: 300) { x, y in
            inBar(y) && ((100..<196).contains(x) || (805...900).contains(x))
        }

        #expect(NetCorners.barBottom(bar, left: barLeft, right: longBarRight, postHeight: 300) == nil)
    }

    @Test("something hanging over the bar doesn't move its edge")
    func hangingOverBar() {
        let bar = mask(width: 1000, height: 300) { x, y in
            (300..<330).contains(x) ? (100..<130).contains(y) : inBar(y)
        }

        #expect(isBarEdge(NetCorners.barBottom(bar, left: barLeft, right: barRight, postHeight: 300)))
    }

    @Test("no crossbar gives no edge")
    func noBar() {
        let bar = mask(width: 1000, height: 300) { _, _ in false }

        #expect(NetCorners.barBottom(bar, left: barLeft, right: barRight, postHeight: 300) == nil)
    }

    @Test("9 visible columns are too few for an edge")
    func nineVisibleColumns() {
        let bar = mask(width: 1000, height: 300) { x, y in inBar(y) && (148..<157).contains(x) }

        #expect(NetCorners.barBottom(bar, left: barLeft, right: barRight, postHeight: 300) == nil)
    }

    @Test("10 visible columns are enough for an edge")
    func tenVisibleColumns() {
        let bar = mask(width: 1000, height: 300) { x, y in inBar(y) && (148..<158).contains(x) }

        #expect(isBarEdge(NetCorners.barBottom(bar, left: barLeft, right: barRight, postHeight: 300)))
    }

    @Test("10 visible columns on an 800-pixel bar are enough for an edge")
    func tenVisibleColumnsUpClose() {
        let bar = mask(width: 1000, height: 300) { x, y in inBar(y) && (196..<206).contains(x) }

        #expect(isBarEdge(NetCorners.barBottom(bar, left: barLeft, right: longBarRight, postHeight: 300)))
    }

    @Test("both top taps on the same spot give no edge")
    func barTapsOnSameSpot() {
        let bar = mask(width: 1000, height: 300) { _, y in inBar(y) }

        #expect(NetCorners.barBottom(bar, left: barLeft, right: barLeft, postHeight: 300) == nil)
    }

    @Test("taps a few pixels off land on the net's true corners")
    func tapsLandOnTrueCorners() {
        #expect(isClose(NetCorners.refine(netTaps, picture: netPicture()), to: netCorners))
    }

    @Test("the bottom corners keep the height of the bottom taps")
    func bottomCornersKeepTapHeight() {
        let taps = [netTaps[0], netTaps[1], Vec2(503, 403), Vec2(108, 413)]
        let answer = [netCorners[0], netCorners[1], Vec2(499.5, 403), Vec2(111.5, 413)]

        #expect(isClose(NetCorners.refine(taps, picture: netPicture()), to: answer))
    }

    @Test("a tilted net still gets its true corners")
    func tiltedNet() {
        let tilted = paintedPicture(640, 480) { x, y in
            let across = Double(x), down = Double(y)
            let leftLean = 0.03 * (down - 100), rightLean = -0.02 * (down - 100), slope = 0.05 * (across - 100)
            let belowBarTop = down >= 99.5 + slope && down < 440
            let onLeftPost = belowBarTop && across >= 99.5 + leftLean && across <= 111.5 + leftLean
            let onRightPost = belowBarTop && across >= 499.5 + rightLean && across <= 511.5 + rightLean
            let onBar = down >= 99.5 + slope && down <= 111.5 + slope && across >= 99.5 + leftLean && across <= 511.5 + rightLean
            return onLeftPost || onRightPost || onBar ? frameRed : lightFloor
        }
        let topLeft = topCorner(postEdge: 111.5, lean: 0.03), topRight = topCorner(postEdge: 499.5, lean: -0.02)
        let bottomRight = Vec2(499.5 - 0.02 * 308, 408), bottomLeft = Vec2(111.5 + 0.03 * 308, 408)
        let taps = [topLeft + Vec2(-3, -3), topRight + Vec2(3, -3), bottomRight + Vec2(3, 0), bottomLeft + Vec2(-3, 0)]

        let corners = NetCorners.refine(taps, picture: tilted)

        #expect(isClose(corners, to: [topLeft, topRight, bottomRight, bottomLeft], within: 0.1))
    }

    @Test("a tap 15 pixels from the corner on a 300-pixel post is corrected")
    func movesFifteenPixels() {
        let taps = [Vec2(96.5, 111.5), netTaps[1], netTaps[2], netTaps[3]]

        #expect(isClose(NetCorners.refine(taps, picture: netPicture()), to: netCorners))
    }

    @Test("a tap 16 pixels from the corner on a 300-pixel post gives no answer")
    func refusesSixteenPixels() {
        let taps = [Vec2(95.5, 111.5), netTaps[1], netTaps[2], netTaps[3]]

        #expect(NetCorners.refine(taps, picture: netPicture()) == nil)
    }

    @Test("a tap 30 pixels from the corner on a 600-pixel post is corrected")
    func movesThirtyPixelsUpClose() {
        let taps = [Vec2(81.5, 111.5), Vec2(503, 108), Vec2(503, 708), Vec2(108, 708)]
        let answer = [Vec2(111.5, 111.5), Vec2(499.5, 111.5), Vec2(499.5, 708), Vec2(111.5, 708)]

        #expect(isClose(NetCorners.refine(taps, picture: netPicture(height: 800)), to: answer))
    }

    @Test("a tap 31 pixels from the corner on a 600-pixel post gives no answer")
    func refusesThirtyOnePixelsUpClose() {
        let taps = [Vec2(80.5, 111.5), Vec2(503, 108), Vec2(503, 708), Vec2(108, 708)]

        #expect(NetCorners.refine(taps, picture: netPicture(height: 800)) == nil)
    }

    @Test("3 taps give no answer")
    func threeTaps() {
        #expect(NetCorners.refine(Array(netTaps[0..<3]), picture: netPicture()) == nil)
    }

    @Test("a hidden left post gives no answer")
    func hiddenLeftPost() {
        #expect(NetCorners.refine(netTaps, picture: netPicture(showLeftPost: false)) == nil)
    }

    @Test("a hidden right post gives no answer")
    func hiddenRightPost() {
        #expect(NetCorners.refine(netTaps, picture: netPicture(showRightPost: false)) == nil)
    }

    @Test("a hidden crossbar gives no answer")
    func hiddenCrossbar() {
        #expect(NetCorners.refine(netTaps, picture: netPicture(showBar: false)) == nil)
    }

    @Test("a net in blue shade gets the same corners")
    func netInShade() {
        #expect(isClose(NetCorners.refine(netTaps, picture: netPicture(frame: Paint(90, 60, 100))), to: netCorners))
    }

    @Test("a shadow across the net gets the same corners")
    func shadowAcrossNet() {
        let picture = netPicture { x, y in
            guard y > 250 else { return nil }
            let onPost = ((100..<112).contains(x) || (500..<512).contains(x)) && y < 440
            return onPost ? Paint(90, 60, 100) : Paint(120, 125, 150)
        }

        #expect(isClose(NetCorners.refine(netTaps, picture: picture), to: netCorners))
    }

    @Test("a black frame gets the same corners")
    func blackFrame() {
        #expect(isClose(NetCorners.refine(netTaps, picture: netPicture(frame: Paint(10, 10, 10))), to: netCorners))
    }

    @Test("a red jacket beside the post gets the same corners")
    func redJacketBesidePost() {
        let picture = netPicture { x, y in
            (125..<140).contains(x) && (200..<260).contains(y) ? frameRed : nil
        }

        #expect(isClose(NetCorners.refine(netTaps, picture: picture), to: netCorners))
    }

    @Test("a white net gives no answer")
    func whiteNet() {
        #expect(NetCorners.refine(netTaps, picture: netPicture(frame: Paint(240, 240, 240))) == nil)
    }

    @Test("a very dark background gives no answer")
    func veryDarkBackground() {
        #expect(NetCorners.refine(netTaps, picture: netPicture(background: Paint(15, 15, 15))) == nil)
    }

    @Test("taps outside the picture give no answer")
    func tapsOutsidePicture() {
        let oneOutside = [netTaps[0], Vec2(900, 108), netTaps[2], netTaps[3]]
        let allOutside = [Vec2(900, 108), Vec2(1300, 108), Vec2(1300, 408), Vec2(900, 408)]

        #expect(NetCorners.refine(oneOutside, picture: netPicture()) == nil)
        #expect(NetCorners.refine(allOutside, picture: netPicture()) == nil)
    }
}

private struct Paint {
    let red: UInt8, green: UInt8, blue: UInt8

    init(_ red: UInt8, _ green: UInt8, _ blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

private let frameRed = Paint(180, 40, 40)
private let lightFloor = Paint(200, 200, 200)
private let postTop = Vec2(110, 50), postBottom = Vec2(110, 350), tallPostBottom = Vec2(110, 650)
private let barLeft = Vec2(100, 107), barRight = Vec2(500, 107), longBarRight = Vec2(900, 107)
private let netTaps = [Vec2(108, 108), Vec2(503, 108), Vec2(503, 408), Vec2(108, 408)]
private let netCorners = [Vec2(111.5, 111.5), Vec2(499.5, 111.5), Vec2(499.5, 408), Vec2(111.5, 408)]

private func isClose(_ found: Vec2, to answer: Vec2, within tolerance: Double) -> Bool {
    abs(found.x - answer.x) <= tolerance && abs(found.y - answer.y) <= tolerance
}

private func isClose(_ found: [Vec2]?, to answer: [Vec2], within tolerance: Double = 1e-6) -> Bool {
    guard let found, found.count == answer.count else { return false }
    return zip(found, answer).allSatisfy { isClose($0, to: $1, within: tolerance) }
}

private func edgePoints(_ count: Int, bad: [Int: Double] = [:], wobble: Double = 0) -> [(t: Double, v: Double)] {
    (0..<count).map { index in
        let side = index.isMultiple(of: 2) ? wobble : -wobble
        return (t: Double(index), v: 100 + 0.5 * Double(index) + (bad[index] ?? 0) + side)
    }
}

private func isTrueLine(_ line: NetCorners.Line?, within tolerance: Double) -> Bool {
    guard let line else { return false }
    return abs(line.at(0) - 100) <= tolerance && abs(line.at(20) - 110) <= tolerance
}

private func findRed(_ red: ClosedRange<Int>..., expectedAt guess: Int, postHeight: Double) -> (Int, Int)? {
    NetCorners.nearestRun(guess, postHeight: postHeight) { index in
        red.contains { $0.contains(index) }
    }
}

private func isRun(_ found: (Int, Int)?, _ start: Int, _ end: Int) -> Bool {
    found?.0 == start && found?.1 == end
}

private func paintedPicture(_ width: Int, _ height: Int, _ paint: (Int, Int) -> Paint) -> Picture {
    var rgb = [UInt8](repeating: 0, count: width * height * 3)
    for y in 0..<height {
        for x in 0..<width {
            let color = paint(x, y), at = (y * width + x) * 3
            rgb[at] = color.red
            rgb[at + 1] = color.green
            rgb[at + 2] = color.blue
        }
    }
    return Picture(width: width, height: height, rgb: rgb)
}

private func isCounted(_ color: Paint) -> Bool {
    let picture = paintedPicture(40, 40) { _, _ in color }
    let taps = [Vec2(10, 10), Vec2(30, 10), Vec2(30, 30), Vec2(10, 30)]
    return NetCorners.postMask(picture, around: taps).at(20, 20)
}

private func allRedMask(postHeight: Double) -> NetCorners.Mask {
    let bottom = 100 + postHeight
    let picture = paintedPicture(640, Int(bottom) + 100) { _, _ in frameRed }
    return NetCorners.postMask(picture, around: [Vec2(200, 100), Vec2(400, 100), Vec2(400, bottom), Vec2(200, bottom)])
}

private func mask(width: Int = 400, height: Int = 700, _ isOn: (Int, Int) -> Bool) -> NetCorners.Mask {
    var on = [Bool](repeating: false, count: width * height)
    for y in 0..<height {
        for x in 0..<width where isOn(x, y) {
            on[y * width + x] = true
        }
    }
    return NetCorners.Mask(width: width, height: height, on: on)
}

private func inPost(_ x: Int) -> Bool {
    (100..<120).contains(x)
}

private func inBar(_ y: Int) -> Bool {
    (100..<115).contains(y)
}

private func hasPostEdges(_ edges: (left: NetCorners.Line, right: NetCorners.Line)?) -> Bool {
    guard let edges else { return false }
    return abs(edges.left.at(200) - 99.5) <= 1e-6 && abs(edges.right.at(200) - 119.5) <= 1e-6
}

private func isBarEdge(_ edge: NetCorners.Line?) -> Bool {
    guard let edge else { return false }
    return abs(edge.at(300) - 114.5) <= 1e-6
}

private func netPicture(height: Int = 480, frame: Paint = frameRed, background: Paint = lightFloor,
                        showLeftPost: Bool = true, showRightPost: Bool = true, showBar: Bool = true,
                        overlay: (Int, Int) -> Paint? = { _, _ in nil }) -> Picture {
    paintedPicture(640, height) { x, y in
        if let painted = overlay(x, y) { return painted }
        let inPostRows = (100..<height - 40).contains(y)
        if showLeftPost && inPostRows && (100..<112).contains(x) { return frame }
        if showRightPost && inPostRows && (500..<512).contains(x) { return frame }
        if showBar && (100..<112).contains(y) && (100..<512).contains(x) { return frame }
        return background
    }
}

private func topCorner(postEdge: Double, lean: Double) -> Vec2 {
    var corner = Vec2(postEdge, 111.5)
    for _ in 0..<20 {
        corner.x = postEdge + lean * (corner.y - 100)
        corner.y = 111.5 + 0.05 * (corner.x - 100)
    }
    return corner
}

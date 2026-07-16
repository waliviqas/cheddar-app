import Testing
import CoreGraphics
@testable import CVPipeline

@Suite("ShotJudge")
struct ShotJudgeTests {

    /*
    - Three flights: a long fast one, a short slow drift, and a two-point flicker
    - Only the long fast one covers real distance at real speed, like a shot does
    - This test will expect exactly that flight back
    */
    @Test("picks the long fast flight as the shot")
    func picksTheShot() throws {
        let shotFlight = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 170, y: 100),
            CGPoint(x: 240, y: 100),
            CGPoint(x: 310, y: 100),
            CGPoint(x: 380, y: 100),
            CGPoint(x: 450, y: 100),
        ]
        let slowDrift = [
            CGPoint(x: 500, y: 300),
            CGPoint(x: 503, y: 300),
            CGPoint(x: 506, y: 301),
            CGPoint(x: 509, y: 301),
        ]
        let flicker = [
            CGPoint(x: 50, y: 50),
            CGPoint(x: 52, y: 51),
        ]

        let picked = try #require(ShotJudge().shot(among: [slowDrift, shotFlight, flicker]))

        #expect(picked == shotFlight)
    }

    /*
    - Only junk flights: a slow drift and a two-point flicker, no real shot anywhere
    - The judge must not crown the least-junky one as champion
    - This test will expect nil back
    */
    @Test("returns nil when no flight is actually a shot")
    func returnsNilForJunkOnly() {
        let slowDrift = [
            CGPoint(x: 500, y: 300),
            CGPoint(x: 503, y: 300),
            CGPoint(x: 506, y: 301),
            CGPoint(x: 509, y: 301),
        ]
        let flicker = [
            CGPoint(x: 50, y: 50),
            CGPoint(x: 52, y: 51),
        ]

        let picked = ShotJudge().shot(among: [slowDrift, flicker])

        #expect(picked == nil)
    }

    /*
    - No flights at all, nothing ever flew
    - This test will expect nil back
    */
    @Test("returns nil when there are no flights")
    func returnsNilForNoFlights() {
        let picked = ShotJudge().shot(among: [])

        #expect(picked == nil)
    }

    /*
    - A zigzag wanderer covers MORE total ground than the straight sprint, but bounces
      up and down and ends where it started - noise, not a shot
    - A shot flies fast and straight, so this test will expect the straight sprint back
    */
    @Test("picks the straight sprint over a farther-wandering zigzag")
    func picksStraightOverZigzag() throws {
        let straightSprint = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 100),
            CGPoint(x: 300, y: 100),
            CGPoint(x: 400, y: 100),
            CGPoint(x: 500, y: 100),
            CGPoint(x: 600, y: 100),
        ]
        let zigzagWanderer = [
            CGPoint(x: 400, y: 300),
            CGPoint(x: 400, y: 380),
            CGPoint(x: 400, y: 300),
            CGPoint(x: 400, y: 380),
            CGPoint(x: 400, y: 300),
            CGPoint(x: 400, y: 380),
            CGPoint(x: 400, y: 300),
            CGPoint(x: 400, y: 380),
            CGPoint(x: 400, y: 300),
        ]
        let slowDrift = [
            CGPoint(x: 500, y: 300),
            CGPoint(x: 503, y: 300),
            CGPoint(x: 506, y: 301),
            CGPoint(x: 509, y: 301),
        ]

        let picked = try #require(ShotJudge().shot(among: [zigzagWanderer, straightSprint, slowDrift]))

        #expect(picked == straightSprint)
    }
}

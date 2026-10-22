import XCTest
@testable import ShopCore

final class CompactNumberTests: XCTestCase {
    func testFormatting() {
        let cases: [(Int, String)] = [
            (0, "0"), (7, "7"), (999, "999"),
            (1_000, "1K"), (1_050, "1.05K"), (1_500, "1.5K"), (1_791, "1.79K"), (1_999, "1.99K"),
            (9_999, "9.99K"), (10_000, "10K"), (12_480, "12.4K"), (99_999, "99.9K"),
            (123_456, "123K"), (999_999, "999K"),
            (1_000_000, "1M"), (2_345_678, "2.34M"), (45_600_000, "45.6M"), (999_999_999, "999M"),
            (1_200_000_000, "1.2B"), (Int(Int32.max), "2.14B"),
            (-1_791, "-1.79K"),
        ]
        for (value, expected) in cases {
            XCTAssertEqual(CompactNumber.format(value), expected, "\(value)")
        }
    }

    func testLabelsStayShort() {
        var value = 1
        while value < 1_000_000_000_000 {
            XCTAssertLessThanOrEqual(CompactNumber.format(value).count, 5, "\(value)")
            value = value * 3 + 7
        }
    }
}

final class ShowcaseStateTests: XCTestCase {
    func testShowcaseStateIsValidAndPlayable() throws {
        let state = ShowcaseState.make(now: testNow, timeZone: utc)
        XCTAssertEqual(SaveCodec.sanitize(state), state, "showcase must already be a valid save")
        var engine = GameEngine(state: state)
        XCTAssertEqual(engine.reputationLevel, 5)
        XCTAssertEqual(engine.state.daily.goals.count, 3)
        XCTAssertEqual(engine.state.currentVisit?.customerId, "dottie")
        XCTAssertTrue(engine.isRegular("dottie"))
        guard case .sold(let r) = try engine.serve(visitId: 140) else { return XCTFail() }
        XCTAssertTrue(r.giftWrapped)
    }
}

import Testing
import Foundation
@testable import Bovexa

struct PBDateTests {
    @Test func parseWithMilliseconds() {
        let date = PBDate.parse("2026-07-24 10:30:00.000Z")
        #expect(date != nil)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date!)
        #expect(comps.year == 2026)
        #expect(comps.month == 7)
        #expect(comps.day == 24)
        #expect(comps.hour == 10)
        #expect(comps.minute == 30)
    }

    @Test func parseWithoutMilliseconds() {
        #expect(PBDate.parse("2026-07-24 10:30:00Z") != nil)
    }

    @Test func parseInvalidStringReturnsNil() {
        #expect(PBDate.parse("niet-een-datum") == nil)
    }
}

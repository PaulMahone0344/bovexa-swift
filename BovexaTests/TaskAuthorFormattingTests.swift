import Testing
import Foundation
@testable import Bovexa

struct TaskAuthorFormattingTests {
    private let now = Date(timeIntervalSince1970: 1_785_182_400) // 27 juli 2026, 12:00 UTC

    @Test func todayShowsOnlyTheTime() {
        let created = now.addingTimeInterval(-2 * 3600)

        let text = TaskAuthorFormatting.label(owner: "Jij", created: created, now: now)

        #expect(text == "Jij · vandaag om \(fmtTime(created))")
    }

    @Test func yesterdayIsNamed() {
        let created = now.addingTimeInterval(-26 * 3600)

        let text = TaskAuthorFormatting.label(owner: "Karim", created: created, now: now)

        #expect(text == "Karim · gisteren om \(fmtTime(created))")
    }

    /// Verder terug: dag en maand erbij, anders weet je niet of "om 09:10" van
    /// vorige week of vorige maand is.
    @Test func olderShowsTheDate() {
        let created = now.addingTimeInterval(-5 * 24 * 3600)

        let text = TaskAuthorFormatting.label(owner: "Nora", created: created, now: now)

        #expect(text == "Nora · 22 jul om \(fmtTime(created))")
    }

    /// De rij toont alleen wie en hoe laat; de datum staat in het detailscherm.
    @Test func shortLabelIsNameAndTimeOnly() {
        let created = now.addingTimeInterval(-5 * 24 * 3600)

        let text = TaskAuthorFormatting.shortLabel(owner: "Nora", created: created)

        #expect(text == "Nora · \(fmtTime(created))")
    }

    private func fmtTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

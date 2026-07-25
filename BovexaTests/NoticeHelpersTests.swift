import Testing
import Foundation
@testable import Bovexa

struct NoticeHelpersTests {
    private func notice(id: String, created: Date, author: String = "u1") -> Notice {
        Notice(id: id, org: "org1", author: author, authorNaam: "Ibrahim", title: nil, body: "Test", created: created)
    }

    // MARK: - hasUnread

    @Test func noUnreadWithoutNotices() {
        #expect(!NoticeHelpers.hasUnread([], lastSeen: nil))
    }

    @Test func unreadWhenNeverSeenAndNoticesExist() {
        let notices = [notice(id: "a", created: Date())]
        #expect(NoticeHelpers.hasUnread(notices, lastSeen: nil))
    }

    @Test func unreadWhenLatestNoticeIsNewerThanLastSeen() {
        let seen = Date(timeIntervalSince1970: 1000)
        let notices = [notice(id: "a", created: Date(timeIntervalSince1970: 2000))]
        #expect(NoticeHelpers.hasUnread(notices, lastSeen: seen))
    }

    @Test func notUnreadWhenLatestNoticeIsOlderThanLastSeen() {
        let seen = Date(timeIntervalSince1970: 3000)
        let notices = [notice(id: "a", created: Date(timeIntervalSince1970: 2000))]
        #expect(!NoticeHelpers.hasUnread(notices, lastSeen: seen))
    }

    // MARK: - relativeTime

    @Test func relativeTimeJustNow() {
        let now = Date(timeIntervalSince1970: 10_000)
        #expect(NoticeHelpers.relativeTime(now, now: now) == "zojuist")
    }

    @Test func relativeTimeMinutesAgo() {
        let now = Date(timeIntervalSince1970: 10_000)
        let then = now.addingTimeInterval(-5 * 60)
        #expect(NoticeHelpers.relativeTime(then, now: now) == "5 min geleden")
    }

    @Test func relativeTimeHoursAgo() {
        let now = Date(timeIntervalSince1970: 100_000)
        let then = now.addingTimeInterval(-3 * 3600)
        #expect(NoticeHelpers.relativeTime(then, now: now) == "3 uur geleden")
    }

    @Test func relativeTimeYesterday() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let then = now.addingTimeInterval(-25 * 3600)
        #expect(NoticeHelpers.relativeTime(then, now: now) == "gisteren")
    }
}

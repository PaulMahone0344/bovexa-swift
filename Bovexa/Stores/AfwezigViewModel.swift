import Foundation

/// Viewmodel voor het afwezig-scherm — geport uit afwezig.tsx (valkuil I). Kiezen: 1e
/// tik = vanaf, 2e tik = t/m (of, als de tweede tik vóór de eerste ligt, schuift
/// "vanaf" gewoon terug). Max 31 dagen; per gekozen dag één create.
@MainActor
final class AfwezigViewModel: ObservableObject {
    @Published var reason: AfwezigReason = .vakantie
    /// Verplichte toelichting bij reason == .anders (klantverzoek 26 juli).
    @Published var andersToelichting: String = ""
    @Published private(set) var from: Date?
    @Published private(set) var to: Date?
    @Published var cursorMonth: Date
    @Published private(set) var saving = false
    @Published var savedAlertMessage: String?
    @Published var saveFailedAlert = false
    /// Schakelaar "Hele dag" (m7 plak 5), standaard aan. Alleen relevant bij één
    /// geselecteerde dag — zie `effectiveHeleDag`.
    @Published var heleDag = true
    @Published var startTime: Date
    @Published var endTime: Date

    private let userId: String
    private let org: String?
    private let token: String
    private let repository: EventRepository
    private let calendar: Calendar

    init(
        userId: String, org: String?, token: String, repository: EventRepository = EventRepository(),
        today: Date = Date(), calendar: Calendar = .current
    ) {
        self.userId = userId
        self.org = org
        self.token = token
        self.repository = repository
        self.calendar = calendar
        cursorMonth = today
        startTime = Self.defaultTime(hour: 9, calendar: calendar, reference: today)
        endTime = Self.defaultTime(hour: 17, calendar: calendar, reference: today)
    }

    var range: [Date] {
        guard let from else { return [] }
        return AfwezigRange.days(from: from, to: to ?? from, calendar: calendar)
    }

    var tooLong: Bool { range.count > AfwezigRange.maxDays }

    /// Beperking uit het plan: een dagdeel kan alleen bij één geselecteerde dag.
    var isSingleDaySelection: Bool { range.count == 1 }

    /// De schakelaar telt alleen mee bij één dag; bij meerdere dagen blijft het
    /// hele dagen, ook als de gebruiker 'm eerder had uitgezet (plan: "de
    /// schakelaar verdwijnt" — geen aparte reset nodig, dit is de ene bron van
    /// waarheid die save() en de UI allebei gebruiken).
    var effectiveHeleDag: Bool { isSingleDaySelection ? heleDag : true }

    private var partialDayRangeIsValid: Bool { effectiveHeleDag || endTime > startTime }

    /// "Anders" blokkeert doorgeven zolang er geen toelichting is (klantverzoek 26 juli).
    private var andersToelichtingIsValid: Bool {
        reason != .anders || !andersToelichting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canSave: Bool { from != nil && !tooLong && !saving && partialDayRangeIsValid && andersToelichtingIsValid }

    /// Titel van het hele-dag-blok: bij "Anders" de ingevulde toelichting, anders
    /// gewoon het label (plan: raw_input blijft wel altijd "afwezig: <reden>").
    private var effectiveTitle: String {
        reason == .anders ? andersToelichting.trimmingCharacters(in: .whitespacesAndNewlines) : reason.label
    }

    private static func defaultTime(hour: Int, calendar: Calendar, reference: Date) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: reference) ?? reference
    }

    func pickDay(_ day: Date) {
        let day = calendar.startOfDay(for: day)
        if from == nil || to != nil {
            from = day
            to = nil
            return
        }
        if let from, day < from {
            self.from = day
            return
        }
        to = day
    }

    func isInRange(_ day: Date) -> Bool {
        guard let from else { return false }
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to ?? from)
        let target = calendar.startOfDay(for: day)
        return target >= start && target <= end
    }

    func shiftMonth(_ delta: Int) {
        cursorMonth = calendar.date(byAdding: .month, value: delta, to: cursorMonth) ?? cursorMonth
    }

    func save() async {
        guard canSave, let from else { return }
        saving = true
        defer { saving = false }

        let days = AfwezigRange.days(from: from, to: to ?? from, calendar: calendar)
        let partial = !effectiveHeleDag
        do {
            for day in days {
                let payload = AfwezigCreatePayload(
                    owner: userId, org: org ?? "", title: effectiveTitle,
                    calendar: org != nil ? "work" : "private",
                    visibility: org != nil ? "company" : "private",
                    start: partial ? AfwezigRange.combine(day: day, time: startTime, calendar: calendar) : day,
                    end: partial ? AfwezigRange.combine(day: day, time: endTime, calendar: calendar) : nil,
                    rawInput: "afwezig: \(reason.label.lowercased())"
                )
                _ = try await repository.createEvent(body: payload.requestBody, token: token)
            }
            savedAlertMessage = successMessage(from: from, to: to)
        } catch {
            saveFailedAlert = true
        }
    }

    private static let monthNames = [
        "januari", "februari", "maart", "april", "mei", "juni",
        "juli", "augustus", "september", "oktober", "november", "december",
    ]

    private func shortDate(_ date: Date) -> String {
        let comps = calendar.dateComponents([.day, .month], from: date)
        let month = Self.monthNames[(comps.month ?? 1) - 1]
        return "\(comps.day ?? 0) \(month.prefix(3))"
    }

    private func successMessage(from: Date, to: Date?) -> String {
        let end = to ?? from
        if to != nil, !calendar.isDate(from, inSameDayAs: end) {
            return "\(reason.label) ingepland van \(shortDate(from)) t/m \(shortDate(end))."
        }
        return "\(reason.label) ingepland op \(shortDate(from))."
    }
}

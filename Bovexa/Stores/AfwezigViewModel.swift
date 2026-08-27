import Foundation

/// Viewmodel voor het afwezigheidsscherm. Je tikt losse dagen aan, kiest hele dag
/// of een tijdvak, en kunt het laten herhalen — elke dag, of alleen op bepaalde
/// weekdagen tot een einddatum. Max 31 dagen per keer; per dag één afspraak.
@MainActor
final class AfwezigViewModel: ObservableObject {
    @Published var reason: AfwezigReason = .vakantie
    /// Verplichte toelichting bij reason == .anders (klantverzoek 26 juli).
    @Published var andersToelichting: String = ""
    /// De aangetikte dagen. Losse dagen mogen: elke tik zet een dag aan of uit,
    /// zodat je bijvoorbeeld alleen maandag en donderdag kunt doorgeven. Was eerst
    /// een van–tot-periode, waardoor alles ertussen er verplicht bij hoorde.
    @Published private(set) var geselecteerdeDagen: Set<Date> = []
    @Published var cursorMonth: Date
    @Published private(set) var saving = false
    @Published var savedAlertMessage: String?
    @Published var saveFailedAlert = false
    /// Hoeveel dagen er al op de server staan; bij een fout halverwege hervat de
    /// volgende poging daar (4c). Gaat op 0 zodra de hele reeks staat, en zodra de
    /// gebruiker een andere periode kiest.
    private var createdDays = 0
    /// Schakelaar "Hele dag" (m7 plak 5), standaard aan. Alleen relevant bij één
    /// geselecteerde dag — zie `effectiveHeleDag`.
    @Published var heleDag = true
    @Published var startTime: Date
    @Published var endTime: Date
    /// De beheerders van het bedrijf. Alleen zij mogen je doorgegeven dagen zien —
    /// niet de hele ploeg. Leeg als de ledenlijst niet geladen kon worden; dan
    /// blijft het blok privé in plaats van dat het per ongeluk teambreed wordt.
    @Published private(set) var beheerderIds: [String] = []
    /// Herhalen aan: de gekozen dag is dan het beginpunt van een reeks in plaats
    /// van een losse dag.
    @Published var herhalen = false
    @Published var herhaalModus: HerhaalModus = .elkeDag
    /// Weekdagen volgens Calendar (1 = zondag ... 7 = zaterdag). Alleen in gebruik
    /// bij `herhaalModus == .geselecteerdeDagen`.
    @Published var herhaalWeekdagen: Set<Int> = []
    /// Tot wanneer de herhaling loopt. Leeg = vier weken vooruit, zodat je niet
    /// per ongeluk een jaar aan blokken aanmaakt.
    @Published var herhaalEinddatum: Date?
    /// Vrije toelichting bij de melding; komt in het notitieveld van de afspraak
    /// en is voor de beheerder te lezen.
    @Published var opmerking = ""

    enum HerhaalModus: String, CaseIterable, Identifiable {
        case elkeDag
        case geselecteerdeDagen

        var id: String { rawValue }

        var label: String {
            switch self {
            case .elkeDag: return "Elke dag"
            case .geselecteerdeDagen: return "Geselecteerde dagen"
            }
        }
    }

    private let userId: String
    private let org: String?
    private let token: String
    private let repository: EventRepository
    private let calendar: Calendar
    let store: BeschikbaarheidStore

    init(
        userId: String, org: String?, token: String, repository: EventRepository = EventRepository(),
        today: Date = Date(), calendar: Calendar = .current,
        store: BeschikbaarheidStore = .shared
    ) {
        self.userId = userId
        self.org = org
        self.token = token
        self.repository = repository
        self.calendar = calendar
        self.store = store
        cursorMonth = today
        startTime = Self.defaultTime(hour: 9, calendar: calendar, reference: today)
        endTime = Self.defaultTime(hour: 17, calendar: calendar, reference: today)
    }

    /// De gekozen dagen op volgorde.
    var range: [Date] { geselecteerdeDagen.sorted() }

    /// Eerste en laatste gekozen dag — voor de bevestigingstekst en de lijst.
    var from: Date? { range.first }
    var to: Date? { range.last }

    /// Wat er echt wordt aangemaakt. Zonder herhalen zijn dat de aangetikte dagen;
    /// met herhalen loopt het vanaf de eerste aangetikte dag door tot de einddatum,
    /// eventueel alleen op de gekozen weekdagen.
    var doorTeGevenDagen: [Date] {
        guard herhalen, let start = range.first else { return range }
        let eind = herhaalEinddatum.map { calendar.startOfDay(for: $0) }
            ?? calendar.date(byAdding: .day, value: 27, to: start)
            ?? start
        guard eind >= start else { return [start] }

        var dagen: [Date] = []
        var cursor = start
        while cursor <= eind, dagen.count < AfwezigRange.maxDays {
            let weekdag = calendar.component(.weekday, from: cursor)
            let hoortErbij = herhaalModus == .elkeDag || herhaalWeekdagen.contains(weekdag)
            if hoortErbij { dagen.append(cursor) }
            guard let volgende = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = volgende
        }
        return dagen
    }

    var tooLong: Bool { doorTeGevenDagen.count > AfwezigRange.maxDays }

    /// Herhalen op "geselecteerde dagen" zonder een enkele weekdag levert niets op.
    private var herhalingIsRond: Bool {
        !herhalen || herhaalModus == .elkeDag || !herhaalWeekdagen.isEmpty
    }

    /// De hele-dag-schakelaar geldt nu ook bij meerdere dagen: kies je drie dagen
    /// met 09:00–13:00, dan krijgt elke gekozen dag dat tijdsblok. Eerder viel de
    /// schakelaar weg zodra je een tweede dag aantikte.
    var effectiveHeleDag: Bool { heleDag }

    private var partialDayRangeIsValid: Bool { effectiveHeleDag || endTime > startTime }

    /// "Anders" blokkeert doorgeven zolang er geen toelichting is (klantverzoek 26 juli).
    private var andersToelichtingIsValid: Bool {
        reason != .anders || !andersToelichting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Beschikbaarheid doorgeven heeft geen reden, dus de toelichting bij "Anders"
    /// mag die knop niet blokkeren — die hoort alleen bij de rode knop.
    func canSave(soort: MeldSoort) -> Bool {
        let redenIsRond = soort == .beschikbaar || andersToelichtingIsValid
        return !doorTeGevenDagen.isEmpty && !tooLong && !saving && partialDayRangeIsValid
            && redenIsRond && herhalingIsRond && !botstMet(soort)
    }

    /// Titel van het hele-dag-blok: bij "Anders" de ingevulde toelichting, anders
    /// gewoon het label (plan: raw_input blijft wel altijd "afwezig: <reden>").
    private var effectiveTitle: String {
        reason == .anders ? andersToelichting.trimmingCharacters(in: .whitespacesAndNewlines) : reason.label
    }

    private static func defaultTime(hour: Int, calendar: Calendar, reference: Date) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: reference) ?? reference
    }

    /// Tikken zet een dag aan of uit. Nog een keer op dezelfde dag tikken haalt
    /// hem dus weer weg.
    func pickDay(_ day: Date) {
        let day = calendar.startOfDay(for: day)
        // Andere keuze = een nieuwe reeks; het hervat-punt van de vorige poging
        // hoort daar niet meer bij (4c).
        createdDays = 0
        if geselecteerdeDagen.contains(day) {
            geselecteerdeDagen.remove(day)
        } else {
            geselecteerdeDagen.insert(day)
        }
    }

    /// Alle dagen van de week waarop deze dag valt erbij — "elke maandag" gaat zo
    /// in één tik in plaats van vier keer bladeren.
    func kiesHeleWeek(van day: Date) {
        createdDays = 0
        let start = calendar.startOfDay(for: day)
        guard let week = calendar.dateInterval(of: .weekOfYear, for: start) else { return }
        var dag = week.start
        while dag < week.end {
            geselecteerdeDagen.insert(calendar.startOfDay(for: dag))
            dag = calendar.date(byAdding: .day, value: 1, to: dag) ?? week.end
        }
    }

    func wisSelectie() {
        createdDays = 0
        geselecteerdeDagen = []
    }

    /// Een doorgegeven melding intrekken: de afspraken gaan van de server af en de
    /// regel verdwijnt uit de lijst. Lukt het verwijderen niet, dan blijft de regel
    /// staan — anders zou de gebruiker denken dat het weg is terwijl het team het
    /// blok nog ziet.
    func trekIn(_ melding: Beschikbaarheidsmelding) async {
        for id in melding.eventIds {
            do {
                try await repository.deleteEvent(recordId: id, token: token)
            } catch {
                saveFailedAlert = true
                return
            }
        }
        store.verwijder(melding.id)
        Haptics.success()
    }

    /// Wat er op een dag al is doorgegeven; leeg als er niets staat. De kalender
    /// kleurt zo'n dag blauw of rood, en de knop voor de andere soort gaat uit:
    /// dezelfde dag kan niet allebei zijn.
    func doorgegevenSoort(op dag: Date) -> MeldSoort? {
        let doel = calendar.startOfDay(for: dag)
        for melding in store.meldingen where melding.dagen.contains(where: { calendar.isDate($0, inSameDayAs: doel) }) {
            return melding.soort
        }
        return nil
    }

    /// Botst de huidige selectie met wat er al staat? Dan mag die soort niet meer.
    func botstMet(_ soort: MeldSoort) -> Bool {
        let ander: MeldSoort = soort == .beschikbaar ? .afwezig : .beschikbaar
        return geselecteerdeDagen.contains { doorgegevenSoort(op: $0) == ander }
    }

    func isInRange(_ day: Date) -> Bool {
        geselecteerdeDagen.contains(calendar.startOfDay(for: day))
    }

    /// Haalt op wie de beheerder is, zodat het doorgegeven blok naar hem toe kan.
    /// Faalt stil, net als elders: zonder ledenlijst blijft het bij een privéblok.
    func laadBeheerders() async {
        guard org != nil, let response = await repository.listMembers(token: token) else { return }
        beheerderIds = response.items
            .filter { $0.role == .admin }
            .map(\.userId)
            .filter { !$0.isEmpty }
    }

    func shiftMonth(_ delta: Int) {
        cursorMonth = calendar.date(byAdding: .month, value: delta, to: cursorMonth) ?? cursorMonth
    }

    func save(soort: MeldSoort = .afwezig) async {
        guard canSave(soort: soort), let from else { return }
        saving = true
        defer { saving = false }

        // De aangetikte dagen, of de hele herhaalreeks als die aanstaat.
        let days = doorTeGevenDagen
        let partial = !effectiveHeleDag
        let titel = soort == .beschikbaar ? "Beschikbaar" : effectiveTitle
        let kijkers = Array(Set([userId] + beheerderIds))
        // De beheerder moet er zijn akkoord op geven; hij krijgt het blok bij zijn
        // meldingen met een knop om goed te keuren of te weigeren. Zonder beheerder
        // in beeld gaat het gewoon door, anders zou je niets kwijt kunnen.
        var beginStatus: [String: String] = [:]
        for id in beheerderIds { beginStatus[id] = "pending" }
        do {
            // Hervatten waar het misging (4c): faalde dag 3 van 5, dan stonden 1 en
            // 2 al op de server en maakte "opnieuw" ze dubbel aan.
            var nieuweIds: [String] = []
            for day in days.dropFirst(createdDays) {
                let payload = AfwezigCreatePayload(
                    owner: userId, org: org ?? "", title: titel,
                    calendar: org != nil ? "work" : "private",
                    // "people" met alleen jou en de beheerder erin: wat je doorgeeft
                    // gaat niemand anders in het team aan. Zonder beheerder in beeld
                    // blijft het privé.
                    visibility: kijkers.count > 1 ? "people" : "private",
                    start: partial ? AfwezigRange.combine(day: day, time: startTime, calendar: calendar) : day,
                    end: partial ? AfwezigRange.combine(day: day, time: endTime, calendar: calendar) : nil,
                    rawInput: soort == .beschikbaar ? "beschikbaar" : "afwezig: \(reason.label.lowercased())",
                    viewers: kijkers,
                    assignee: beheerderIds,
                    assigneeStatus: beginStatus,
                    notes: opmerking
                )
                let aangemaakt = try await repository.createEvent(body: payload.requestBody, token: token)
                nieuweIds.append(aangemaakt.id)
                createdDays += 1
            }
            createdDays = 0
            onthoud(soort: soort, titel: titel, days: days, partial: partial, eventIds: nieuweIds)
            wisSelectie()
            // Planner en Editor gaven wél een succes-haptic, dit scherm niet (5b).
            Haptics.success()
            savedAlertMessage = successMessage(titel: titel, from: from, to: to)
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

    /// De doorgegeven titel, niet `reason.label`: bij "Anders" zei de bevestiging
    /// letterlijk "Anders ingepland op 19 aug", terwijl de afspraak de ingevulde
    /// toelichting als titel krijgt (4m).
    private func successMessage(titel: String, from: Date, to: Date?) -> String {
        let dagen = range
        if dagen.count == 1 {
            return "\(titel) ingepland op \(shortDate(from))."
        }
        // Losse dagen mogen, dus het aantal noemen; "van 26 t/m 30" zou suggereren
        // dat alles ertussen er ook bij hoort.
        let opsomming = dagen.map(shortDate).joined(separator: ", ")
        return "\(titel) ingepland op \(dagen.count) dagen: \(opsomming)."
    }

    /// Zet de melding in de lijst onder de knoppen. De blokken staan al op de
    /// server; dit onthoudt alleen wát er is doorgegeven — zie BeschikbaarheidStore.
    private func onthoud(soort: MeldSoort, titel: String, days: [Date], partial: Bool, eventIds: [String]) {
        guard !days.isEmpty else { return }
        store.voegToe(
            Beschikbaarheidsmelding(
                id: UUID().uuidString,
                soort: soort,
                reden: soort == .beschikbaar ? "" : reason.label,
                titel: titel,
                dagen: days,
                eventIds: eventIds,
                heleDag: !partial,
                startTijd: partial ? startTime : nil,
                eindTijd: partial ? endTime : nil,
                gemeldOp: Date()
            )
        )
    }
}

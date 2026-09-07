import Foundation

/// agenda_events — alleen velden die milestone 1 gebruikt (Vandaag/Agenda/detail).
/// Defensief decoderen (valkuil B): oude/afwijkende server-vormen mogen nooit crashen.
/// Gelijkheid/hash op id: na recurrence-expansie is dat de synthetische
/// "recordId:YYYY-MM-DD" (valkuil A) — al uniek per bezetting, geen dictionary-
/// vergelijking nodig (assigneeStatus is geen Hashable).
struct AgendaEvent: Decodable, Identifiable {
    let id: String
    let owner: String
    let calendar: String?
    let category: BovexaTheme.Category?
    let title: String
    let start: Date
    let end: Date?
    let allDay: Bool
    let recurrence: String?
    let location: String?
    let notes: String?
    let klantNaam: String?
    let assigneeStatus: [String: String]
    /// Wanneer het record is aangemaakt (PocketBase `created`). Gebruikt om de
    /// beheerder te laten zien wat er nieuw is ingevoerd door het team.
    let created: Date?
    let seriesId: String?
    let occurrenceDate: String?
    let org: String?
    let visibilityRaw: String?
    let viewers: [String]
    let assignee: [String]
    let reminderMin: Int?
    /// Alle gekozen herinneringen in minuten vooraf (json-veld `reminders`, sinds
    /// 7 sep 2026). Ontbreekt het veld of is het leeg — oude afspraken, of de
    /// RN-app die alleen `reminder_min` schrijft — dan staat hier alsnog die ene
    /// tijd, zodat de rest van de app maar één lijst hoeft te kennen.
    let reminders: [Int]
    let klantTelefoon: String?
    /// Label-id (m7, agenda_labels). Ontbreekt of verwijst niet meer naar een
    /// bestaand label: EventHelpers.eventColor valt dan netjes terug (valkuil H).
    let label: String?
    /// Contact-id (m8, agenda_contacten). Ontbreekt bij oude afspraken (valkuil D):
    /// ContactDisplay valt dan terug op klantNaam/klantTelefoon.
    let contact: String?
    /// Alle gekoppelde contacten (relatieveld `contacten`, meerdere, sinds
    /// 7 sep 2026). De eerste is dezelfde als `contact`: dát is de klant van de
    /// afspraak, de rest zijn medegenodigden. Leeg bij afspraken van vóór dit veld.
    let contacten: [String]
    let expand: Expand?
    /// Extern event (m9, valkuil B) — komt nooit uit PocketBase, alleen uit een externe
    /// agenda via EventKit. Blokkeert bewerken/verwijderen/toewijzen/zichtbaarheid/
    /// label/herinneringen expliciet, in plaats van te leunen op een leeg `owner`-veld.
    let isExternal: Bool

    struct Expand: Decodable, Equatable {
        let contact: AgendaContact?
        /// PocketBase geeft een meervoudige relatie als array terug, maar een oudere
        /// server (of een aangepaste maxSelect) kan er één los object van maken —
        /// allebei toestaan, want dit is puur weergave.
        let contacten: [AgendaContact]

        init(contact: AgendaContact?, contacten: [AgendaContact] = []) {
            self.contact = contact
            self.contacten = contacten
        }

        enum CodingKeys: String, CodingKey {
            case contact, contacten
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            contact = (try? c.decodeIfPresent(AgendaContact.self, forKey: .contact)) ?? nil
            if let lijst = (try? c.decodeIfPresent([AgendaContact].self, forKey: .contacten)) ?? nil {
                contacten = lijst
            } else if let een = (try? c.decodeIfPresent(AgendaContact.self, forKey: .contacten)) ?? nil {
                contacten = [een]
            } else {
                contacten = []
            }
        }
    }

    init(
        id: String, owner: String, calendar: String?, category: BovexaTheme.Category?,
        title: String, start: Date, end: Date?, allDay: Bool, recurrence: String?,
        location: String?, notes: String?, klantNaam: String?,
        assigneeStatus: [String: String], seriesId: String?, occurrenceDate: String?,
        created: Date? = nil,
        org: String? = nil, visibilityRaw: String? = nil, viewers: [String] = [],
        assignee: [String] = [], reminderMin: Int? = nil, reminders: [Int]? = nil,
        klantTelefoon: String? = nil,
        label: String? = nil, contact: String? = nil, contacten: [String]? = nil,
        expand: Expand? = nil,
        isExternal: Bool = false
    ) {
        self.id = id
        self.owner = owner
        self.calendar = calendar
        self.category = category
        self.title = title
        self.start = start
        self.end = end
        self.allDay = allDay
        self.recurrence = recurrence
        self.location = location
        self.notes = notes
        self.klantNaam = klantNaam
        self.assigneeStatus = assigneeStatus
        self.created = created
        self.seriesId = seriesId
        self.occurrenceDate = occurrenceDate
        self.org = org
        self.visibilityRaw = visibilityRaw
        self.viewers = viewers
        self.assignee = assignee
        self.reminderMin = reminderMin
        // nil ⇒ afleiden uit reminder_min: één ingang, dus geen enkele kopie hoeft
        // de terugval zelf nog te herhalen.
        self.reminders = reminders ?? ReminderOption.opschonen([reminderMin ?? 0])
        self.klantTelefoon = klantTelefoon
        self.label = label
        self.contact = contact
        // nil ⇒ afleiden uit `contact`, zodat elke kopie en elke oude afspraak
        // dezelfde lijst kent zonder dat de terugval overal herhaald wordt.
        self.contacten = contacten ?? [contact].compactMap { $0 }.filter { !$0.isEmpty }
        self.expand = expand
        self.isExternal = isExternal
    }

    /// Kopie met andere id/tijd/serie — gebruikt door RecurrenceExpander om een
    /// uitgeklapte losse dag te maken zonder de rest van de afspraak te herhalen.
    func withOccurrence(id: String, start: Date, end: Date?, seriesId: String, occurrenceDate: String) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: owner, calendar: calendar, category: category, title: title,
            start: start, end: end, allDay: allDay, recurrence: recurrence, location: location,
            notes: notes, klantNaam: klantNaam, assigneeStatus: assigneeStatus,
            seriesId: seriesId, occurrenceDate: occurrenceDate, created: created,
            org: org, visibilityRaw: visibilityRaw, viewers: viewers,
            assignee: assignee, reminderMin: reminderMin, reminders: reminders,
            klantTelefoon: klantTelefoon, label: label,
            contact: contact, contacten: contacten, expand: expand, isExternal: isExternal
        )
    }

    /// Kopie met bijgewerkte assignee_status — voor optimistische UI-updates bij
    /// accepteren/weigeren (valkuil B), zonder de rest van de afspraak aan te raken.
    func withAssigneeStatus(_ assigneeStatus: [String: String]) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: owner, calendar: calendar, category: category, title: title,
            start: start, end: end, allDay: allDay, recurrence: recurrence, location: location,
            notes: notes, klantNaam: klantNaam, assigneeStatus: assigneeStatus,
            seriesId: seriesId, occurrenceDate: occurrenceDate, created: created,
            org: org, visibilityRaw: visibilityRaw, viewers: viewers,
            assignee: assignee, reminderMin: reminderMin, reminders: reminders,
            klantTelefoon: klantTelefoon, label: label,
            contact: contact, contacten: contacten, expand: expand, isExternal: isExternal
        )
    }

    /// Kopie met bijgewerkte visibility/viewers — voor optimistische UI-updates bij
    /// het wijzigen van de zichtbaarheid.
    func withVisibility(_ visibilityRaw: String, viewers: [String]) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: owner, calendar: calendar, category: category, title: title,
            start: start, end: end, allDay: allDay, recurrence: recurrence, location: location,
            notes: notes, klantNaam: klantNaam, assigneeStatus: assigneeStatus,
            seriesId: seriesId, occurrenceDate: occurrenceDate, created: created,
            org: org, visibilityRaw: visibilityRaw, viewers: viewers,
            assignee: assignee, reminderMin: reminderMin, reminders: reminders,
            klantTelefoon: klantTelefoon, label: label,
            contact: contact, contacten: contacten, expand: expand, isExternal: isExternal
        )
    }

    /// Kopie met ander label — voor optimistische UI-updates bij het kiezen van
    /// een label in EventEditor/planner-bevestiging (m7).
    func withLabel(_ label: String?) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: owner, calendar: calendar, category: category, title: title,
            start: start, end: end, allDay: allDay, recurrence: recurrence, location: location,
            notes: notes, klantNaam: klantNaam, assigneeStatus: assigneeStatus,
            seriesId: seriesId, occurrenceDate: occurrenceDate, created: created,
            org: org, visibilityRaw: visibilityRaw, viewers: viewers,
            assignee: assignee, reminderMin: reminderMin, reminders: reminders,
            klantTelefoon: klantTelefoon, label: label,
            contact: contact, contacten: contacten, expand: expand, isExternal: isExternal
        )
    }

    /// Kopie met andere contacten — voor optimistische UI-updates bij het kiezen in
    /// EventEditor (m8). De eerste blijft de klant (`contact`). `expand` wordt niet
    /// meegenomen: de server stuurt die pas terug bij de volgende fetch.
    func withContacts(_ contacten: [String]) -> AgendaEvent {
        withContact(contacten.first, contacten: contacten)
    }

    func withContact(_ contact: String?, contacten: [String]? = nil) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: owner, calendar: calendar, category: category, title: title,
            start: start, end: end, allDay: allDay, recurrence: recurrence, location: location,
            notes: notes, klantNaam: klantNaam, assigneeStatus: assigneeStatus,
            seriesId: seriesId, occurrenceDate: occurrenceDate, created: created,
            org: org, visibilityRaw: visibilityRaw, viewers: viewers,
            assignee: assignee, reminderMin: reminderMin, reminders: reminders,
            klantTelefoon: klantTelefoon, label: label,
            contact: contact, contacten: contacten, expand: nil, isExternal: isExternal
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, owner, calendar, category, title, start, end
        case allDay = "all_day"
        case recurrence, location, notes
        case klantNaam = "klant_naam"
        case assigneeStatus = "assignee_status"
        case seriesId = "series_id"
        case occurrenceDate = "occurrence_date"
        case org
        case visibilityRaw = "visibility"
        case viewers, assignee
        case reminderMin = "reminder_min"
        case reminders
        case klantTelefoon = "klant_telefoon"
        case label, contact, contacten, expand
        case created
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        owner = try c.decode(String.self, forKey: .owner)
        calendar = Self.decodeOptional(c, .calendar)
        category = Self.decodeOptional(c, .category)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""

        let startRaw = (try? c.decode(String.self, forKey: .start)) ?? ""
        start = PBDate.parse(startRaw) ?? Date(timeIntervalSince1970: 0)
        end = Self.decodeOptional(c, .end, as: String.self).flatMap(PBDate.parse)

        allDay = Self.decodeOptional(c, .allDay) ?? false
        recurrence = Self.decodeOptional(c, .recurrence)
        location = Self.decodeOptional(c, .location)
        notes = Self.decodeOptional(c, .notes)
        klantNaam = Self.decodeOptional(c, .klantNaam)
        assigneeStatus = Self.decodeOptional(c, .assigneeStatus) ?? [:]
        created = Self.decodeOptional(c, .created, as: String.self).flatMap(PBDate.parse)
        seriesId = Self.decodeOptional(c, .seriesId)
        occurrenceDate = Self.decodeOptional(c, .occurrenceDate)
        org = Self.decodeOptional(c, .org)
        visibilityRaw = Self.decodeOptional(c, .visibilityRaw)
        viewers = Self.decodeOptional(c, .viewers) ?? []
        assignee = Self.decodeAssigneeIds(c)
        let reminderMinRaw: Int? = Self.decodeOptional(c, .reminderMin)
        reminderMin = reminderMinRaw
        // Het json-veld mag ontbreken, null zijn of (bij een record dat de RN-app
        // schreef) leeg blijven; dan telt reminder_min nog steeds.
        let lijst = ReminderOption.opschonen(Self.decodeOptional(c, .reminders) ?? [])
        reminders = lijst.isEmpty ? ReminderOption.opschonen([reminderMinRaw ?? 0]) : lijst
        klantTelefoon = Self.decodeOptional(c, .klantTelefoon)
        label = Self.decodeOptional(c, .label)
        let contactRaw: String? = Self.decodeOptional(c, .contact)
        contact = contactRaw
        // Ontbreekt het veld (of stuurt de server nog een los id), dan blijft het
        // bij het ene contact dat er al was.
        if let lijst: [String] = Self.decodeOptional(c, .contacten), !lijst.isEmpty {
            contacten = lijst.filter { !$0.isEmpty }
        } else if let een: String = Self.decodeOptional(c, .contacten), !een.isEmpty {
            contacten = [een]
        } else {
            contacten = [contactRaw].compactMap { $0 }.filter { !$0.isEmpty }
        }
        expand = Self.decodeOptional(c, .expand)
        isExternal = false
    }

    /// Ontbrekende sleutel, null, of een onverwacht type → nil in plaats van crash.
    private static func decodeOptional<T: Decodable>(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys, as type: T.Type = T.self) -> T? {
        (try? c.decodeIfPresent(T.self, forKey: key)) ?? nil
    }

    /// Oudere records hebben nog een los string-id i.p.v. een array (vóór punt F) —
    /// zie assigneesOf() in de RN-app. Beide vormen normaliseren naar [String].
    private static func decodeAssigneeIds(_ c: KeyedDecodingContainer<CodingKeys>) -> [String] {
        if let array: [String] = decodeOptional(c, .assignee) { return array }
        if let single: String = decodeOptional(c, .assignee), !single.isEmpty { return [single] }
        return []
    }
}

extension AgendaEvent: Hashable {
    static func == (lhs: AgendaEvent, rhs: AgendaEvent) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

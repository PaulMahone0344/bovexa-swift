import Foundation

/// Waarvoor het formulier openstaat (M12): een bestaande afspraak bewerken, of een
/// nieuwe aanmaken vanuit een voorzet. Eén formulier, twee modi — een tweede
/// aanmaakscherm zou dezelfde velden nóg een keer moeten bijhouden.
enum EditorMode {
    case edit(AgendaEvent)
    case create(NieuweAfspraakSeed)
}

/// Viewmodel voor het afspraak-formulier. Opslaan: titel-check, dubbele-boeking-check
/// (fetchOwnEvents + findOverlap), dan updateEvent (valkuil E) of createEvent
/// (M12, source 'manual') + herinnering plannen + sync naar de iPhone Agenda.
@MainActor
final class EventEditorViewModel: ObservableObject {
    @Published var title: String
    @Published var category: BovexaTheme.Category
    @Published private(set) var start: Date
    @Published private(set) var durationMin: Int
    @Published var notes: String
    @Published var klantNaam: String
    @Published var klantTelefoon: String
    @Published var reminderMin: Int
    @Published var assignee: [String]
    @Published var label: String?
    @Published var contactId: String?
    /// Alleen in create-modus in beeld: bij bewerken wijzig je de zichtbaarheid in
    /// het afspraak-detail. Zonder org negeert de payload-bouwer deze keuze.
    @Published var visibility: String

    /// Duur van een nieuwe afspraak als het bedrijf geen standaardduur heeft.
    static let fallbackDurationMin = 60

    /// Kiezen van een contact vult klant_naam/klant_telefoon mee: een collega kan het
    /// privécontact niet uitlezen en zou anders geen klant zien op een gedeelde
    /// afspraak. Loslaten zet de oorspronkelijke tekst van de afspraak terug (bij een
    /// nieuwe afspraak is die er niet, dan blijft het leeg).
    func selectContact(_ contact: AgendaContact?) {
        contactId = contact?.id
        klantNaam = contact?.naam ?? originalEvent?.klantNaam ?? ""
        klantTelefoon = contact?.telefoon ?? originalEvent?.klantTelefoon ?? ""
    }

    @Published private(set) var isSaving = false
    @Published var titleMissingAlert = false
    @Published var saveFailedAlert = false
    /// Niet-nil ⇒ caller toont "Dubbele boeking"-alert; bevestigen roept saveConfirmed() aan.
    @Published var overlapEvent: AgendaEvent?

    let mode: EditorMode

    /// De afspraak die bewerkt wordt; nil zolang er een nieuwe wordt aangemaakt.
    var originalEvent: AgendaEvent? {
        if case .edit(let event) = mode { return event }
        return nil
    }

    var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    /// Eigenaar van de afspraak: bij bewerken de bestaande eigenaar, bij aanmaken de
    /// ingelogde gebruiker. Bepaalt óók wiens agenda de dubbele-boeking-check leest.
    private let ownerId: String
    /// `user.default_org`, leeg als er geen bedrijf is (PocketBase geeft een lege
    /// relatie terug als ""). Leeg ⇒ geen toewijzen, geen label, altijd privé.
    private let org: String
    private let token: String
    private let repository: EventRepository
    private let reminderService: ReminderService
    private let deviceCalendarService: DeviceCalendarService

    init(
        mode: EditorMode, ownerId: String, org: String, token: String,
        defaultDurationMin: Int = EventEditorViewModel.fallbackDurationMin, now: Date = Date(),
        repository: EventRepository = EventRepository(), reminderService: ReminderService = ReminderService(),
        deviceCalendarService: DeviceCalendarService = DeviceCalendarService()
    ) {
        self.mode = mode
        self.ownerId = ownerId
        self.org = org
        self.token = token
        self.repository = repository
        self.reminderService = reminderService
        self.deviceCalendarService = deviceCalendarService

        switch mode {
        case .edit(let event):
            title = event.title
            category = event.category ?? .work
            start = event.start
            durationMin = event.end.map { max(15, Int($0.timeIntervalSince(event.start) / 60)) } ?? 30
            notes = event.notes ?? ""
            klantNaam = event.klantNaam ?? ""
            klantTelefoon = event.klantTelefoon ?? ""
            reminderMin = event.reminderMin ?? 0
            assignee = event.assignee
            label = event.label
            contactId = event.contact
            visibility = "private"
        case .create(let seed):
            // Defaults gelijk aan de planner: privé, geen herinnering, geen
            // toewijzing, categorie werk.
            //
            // Getypte zin uit de plan-pill wordt de titel. Hij staat er alleen als
            // je "zelf invullen" koos; die tekst weggooien betekent dat je 'm
            // opnieuw moet intikken. Datum en tijd leest alleen de AI eruit, dus
            // die blijven op de voorzet staan.
            title = seed.trimmedText ?? ""
            category = .work
            start = seed.startDate(now: now)
            durationMin = max(15, defaultDurationMin)
            notes = ""
            klantNaam = ""
            klantTelefoon = ""
            reminderMin = 0
            assignee = []
            label = nil
            contactId = nil
            visibility = "private"
        }
    }

    /// Bestaande ingang (valkuil F): bewerken blijft precies zo werken.
    convenience init(
        event: AgendaEvent, token: String,
        repository: EventRepository = EventRepository(), reminderService: ReminderService = ReminderService()
    ) {
        self.init(
            mode: .edit(event), ownerId: event.owner, org: event.org ?? "", token: token,
            repository: repository, reminderService: reminderService
        )
    }

    func shiftDay(_ days: Int) {
        start = EventEditorStepping.shiftDay(start, by: days)
    }

    func shiftStart(minutes: Int) {
        start = EventEditorStepping.shiftMinutes(start, by: minutes)
    }

    func changeDuration(by delta: Int) {
        durationMin = EventEditorStepping.clampDuration(durationMin, delta: delta)
    }

    /// Titel-check + dubbele-boeking-check. Bij overlap zet dit `overlapEvent` in
    /// plaats van meteen op te slaan — de caller toont de alert.
    func save() async -> AgendaEvent? {
        // isSaving stond pas in performSave aan; tijdens de dubbele-boeking-check
        // (netwerk) bleef "Opslaan" actief en startte een tweede tik een tweede
        // ronde — twee PATCHes en twee overlap-alerts.
        guard !isSaving else { return nil }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            titleMissingAlert = true
            return nil
        }
        isSaving = true
        defer { isSaving = false }
        let end = start.addingTimeInterval(Double(durationMin) * 60)
        do {
            let own = try await repository.fetchOwnEvents(userId: ownerId, token: token)
            // Bij aanmaken is er nog geen eigen record om over te slaan.
            let excludeId = originalEvent.map(EventHelpers.eventRecordId)
            if let overlap = EventOverlap.findOverlap(in: own, start: start, end: end, excludeId: excludeId) {
                overlapEvent = overlap
                return nil
            }
        } catch {
            saveFailedAlert = true
            return nil
        }
        return await performSave(end: end)
    }

    /// "Toch plannen" op de dubbele-boeking-alert — slaat direct op zonder opnieuw te checken.
    func saveConfirmed() async -> AgendaEvent? {
        overlapEvent = nil
        let end = start.addingTimeInterval(Double(durationMin) * 60)
        return await performSave(end: end)
    }

    private func performSave(end: Date) async -> AgendaEvent? {
        isSaving = true
        defer { isSaving = false }

        switch mode {
        case .edit(let event):
            return await update(event: event, end: end)
        case .create:
            return await create(end: end)
        }
    }

    private func update(event: AgendaEvent, end: Date) async -> AgendaEvent? {
        let payload = EventEditorPayloadBuilder.build(
            title: title, category: category, start: start, end: end, notes: notes,
            klantNaam: klantNaam, klantTelefoon: klantTelefoon, reminderMin: reminderMin,
            assignee: assignee, originalEvent: event, label: label, contact: contactId
        )
        do {
            let updated = try await repository.updateEvent(recordId: EventHelpers.eventRecordId(event), payload: payload, token: token)
            await reminderService.schedule(eventId: updated.id, title: updated.title, start: updated.start, minutesBefore: reminderMin)
            return updated
        } catch {
            saveFailedAlert = true
            return nil
        }
    }

    /// M12: dezelfde create-payload als de planner, met source 'manual' en een lege
    /// raw_input. De herinnering hangt aan het id dat de server teruggeeft — een
    /// zelfbedacht id zou nooit meer op te ruimen zijn. Sinds 21 aug gaat een
    /// handmatige afspraak ook naar de iPhone Agenda, net als de AI-route.
    private func create(end: Date) async -> AgendaEvent? {
        let hasOrg = !org.isEmpty
        let payload = AppointmentPayloadBuilder.buildManual(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            start: start,
            end: end,
            ownerId: ownerId,
            org: hasOrg ? org : nil,
            visibility: visibility,
            assignees: assignee,
            reminderMin: reminderMin,
            label: hasOrg ? label : nil,
            contact: contactId,
            klantNaam: klantNaam.trimmingCharacters(in: .whitespacesAndNewlines),
            klantTelefoon: klantTelefoon.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            let created = try await repository.createEvent(body: payload.requestBody, token: token)
            if reminderMin > 0 {
                await reminderService.schedule(eventId: created.id, title: created.title, start: created.start, minutesBefore: reminderMin)
            }
            // De server bepaalt start en eind; het formulier kan afgerond hebben.
            await deviceCalendarService.sync(
                title: created.title, start: created.start,
                end: created.end ?? created.start.addingTimeInterval(Double(durationMin) * 60)
            )
            return created
        } catch {
            saveFailedAlert = true
            return nil
        }
    }
}

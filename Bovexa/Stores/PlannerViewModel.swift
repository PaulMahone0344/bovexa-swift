import Foundation

/// Gespreks- en bevestig-state voor de AI-planner — geport uit useAiPlanner.ts. Stuurt
/// elke beurt de volledige historie naar de backend en mapt het antwoord naar een
/// chat-thread. De thread overleeft het scherm: hydrate/persist via PlannerThreadStore,
/// gedebouncet (valkuil F). confirm() doet de dubbele-boeking-check (valkuil G),
/// creëert de voorstellen (valkuilen A/C/D/E), plant herinneringen en synct optioneel
/// naar de iPhone Agenda (valkuil H).
@MainActor
final class PlannerViewModel: ObservableObject {
    @Published private(set) var thread: [ThreadItem] = []
    @Published private(set) var loading = false
    @Published private(set) var ready: [ProposedAppointment]?

    /// Zichtbaarheid bij bevestigen (alleen relevant met een org): "private"/"company".
    @Published var visibility = "private"
    @Published var viewers: [String] = []
    @Published var reminderMin = 0
    @Published var assignee: [String] = []
    @Published var label: String?
    @Published var contactId: String?
    /// Naam/telefoon van het gekozen contact, meegeschreven als klant_naam zodat een
    /// collega de klant blijft zien — hij kan het privécontact zelf niet uitlezen.
    @Published private(set) var contactNaam: String?
    @Published private(set) var contactTelefoon: String?

    func selectContact(_ contact: AgendaContact?) {
        contactId = contact?.id
        contactNaam = contact?.naam
        contactTelefoon = contact?.telefoon
    }

    @Published private(set) var saving = false
    /// Niet-nil ⇒ caller toont "Dubbele boeking"-alert; proceedPastOverlap() gaat door,
    /// cancelOverlap() breekt de hele bevestiging af.
    @Published var overlapEvent: AgendaEvent?
    @Published var saveFailedAlert = false
    /// Datum van het eerste voorstel ná een geslaagde bevestiging — de caller
    /// navigeert hierop terug naar Agenda en dismisst het scherm.
    @Published private(set) var confirmedDate: Date?

    private let userId: String
    private let token: String
    private let org: String?
    private let api: PlannerAPI
    private let store: PlannerThreadStore
    private let repository: EventRepository
    private let reminderService: ReminderService
    private let deviceCalendarService: DeviceCalendarService
    private let saveDebounceNanoseconds: UInt64

    private var apiHistory: [ChatTurn] = []
    private var rawInput = ""
    private var idCounter = 0
    private var saveTask: Task<Void, Never>?
    /// Hoeveel van de voorgestelde afspraken al op de server staan. Nodig omdat
    /// "Zet in agenda" er meerdere in één keer aanmaakt: bij een fout halverwege
    /// hervat de volgende poging hier (4c). Reset zet 'm op 0.
    private var createdCount = 0
    private var hydrated = false

    private var ownEvents: [AgendaEvent] = []
    private var overlapCheckIndex = 0

    /// Voor AssigneePickerView ("jezelf" wordt niet als optie getoond).
    var ownerId: String { userId }

    init(
        userId: String, token: String, org: String? = nil, api: PlannerAPI = PlannerAPI(),
        store: PlannerThreadStore = PlannerThreadStore(), repository: EventRepository = EventRepository(),
        reminderService: ReminderService = ReminderService(), deviceCalendarService: DeviceCalendarService = DeviceCalendarService(),
        saveDebounceNanoseconds: UInt64 = 300_000_000
    ) {
        self.userId = userId
        self.token = token
        self.org = org
        self.api = api
        self.store = store
        self.repository = repository
        self.reminderService = reminderService
        self.deviceCalendarService = deviceCalendarService
        self.saveDebounceNanoseconds = saveDebounceNanoseconds
    }

    private func nextId() -> String {
        idCounter += 1
        return String(idCounter)
    }

    /// Opgeslagen gesprek terugzetten — eenmalig, bij openen van het scherm.
    func hydrate() {
        guard !hydrated else { return }
        hydrated = true
        guard let saved = store.load(userId: userId), !saved.thread.isEmpty else { return }
        thread = saved.thread
        apiHistory = saved.api
        rawInput = saved.raw
        idCounter = saved.thread.compactMap { Int($0.id) }.max() ?? 0
        // Alleen weer bevestigbaar als het gesprek op een voorstel eindigde.
        if let last = saved.thread.last, last.kind == .proposal {
            ready = last.appointments
            visibility = Self.defaultVisibility(for: last.appointments)
        }
    }

    func sendText(_ text: String) async {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !loading else { return }
        ready = nil
        // Oude concept-afspraak(en) horen niet meer bij het nieuwe bericht — anders
        // blijft de vorige ConceptCard hangen naast het nieuwe voorstel.
        thread = thread.filter { $0.kind != .proposal }
        thread.append(ThreadItem(id: nextId(), kind: .user, text: input))
        apiHistory.append(ChatTurn(role: .user, content: input))
        if rawInput.isEmpty { rawInput = input }
        await callPlanner()
        scheduleSave()
    }

    func chooseOption(_ option: String) async {
        await sendText(option)
    }

    func retry() async {
        guard !loading else { return }
        // Laatste fout-item weghalen, dezelfde historie opnieuw proberen.
        if thread.last?.kind == .error { thread.removeLast() }
        await callPlanner()
        scheduleSave()
    }

    func reset() {
        thread = []
        ready = nil
        apiHistory = []
        rawInput = ""
        idCounter = 0
        saveTask?.cancel()
        store.clear(userId: userId)
        visibility = "private"
        viewers = []
        reminderMin = 0
        assignee = []
        label = nil
        // Zonder dit lift het contact van het vorige gesprek mee naar de volgende
        // afspraak; onzichtbaar, want "Details" staat standaard dicht.
        selectContact(nil)
        overlapEvent = nil
        overlapCheckIndex = 0
        ownEvents = []
        createdCount = 0
    }

    private func callPlanner() async {
        loading = true
        defer { loading = false }
        do {
            let plan = try await api.requestPlan(messages: apiHistory, token: token)
            let said = plan.status == .needsClarification ? (plan.question ?? plan.message) : plan.message
            apiHistory.append(ChatTurn(role: .assistant, content: said))

            if plan.status == .needsClarification {
                thread.append(ThreadItem(id: nextId(), kind: .question, text: said, options: plan.options))
            } else {
                thread.append(ThreadItem(id: nextId(), kind: .proposal, text: plan.message, appointments: plan.appointments))
                ready = plan.appointments
                visibility = Self.defaultVisibility(for: plan.appointments)
            }
        } catch {
            // Geen assistant-beurt toevoegen → retry verstuurt dezelfde historie opnieuw.
            let message = (error as? PlannerAPIError)?.message ?? "Er ging iets mis. Probeer het nog een keer."
            thread.append(ThreadItem(id: nextId(), kind: .error, text: message))
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.saveDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            self.persist()
        }
    }

    private func persist() {
        if thread.isEmpty {
            store.clear(userId: userId)
            return
        }
        store.save(SavedConversation(thread: thread, api: apiHistory, raw: rawInput), userId: userId)
    }

    /// Valkuil C: standaard-zichtbaarheid volgt de AI-categorie (work/focus → Bedrijf,
    /// anders Privé); de gebruiker kan het in de VisibilityPickerView omzetten.
    private static func defaultVisibility(for appointments: [ProposedAppointment]) -> String {
        appointments.contains { $0.category == .work || $0.category == .focus } ? "company" : "private"
    }

    // MARK: - Bevestigen (plak 3)

    /// "Zet in agenda". Valkuil G: eerst alle voorstellen checken op een dubbele
    /// boeking (één voor één, met een alert per overlap) vóórdat er iets wordt
    /// aangemaakt — bevestigt de gebruiker "Aanpassen", dan breekt dit hele proces af.
    func confirm() async {
        guard let ready, !ready.isEmpty, !saving else { return }
        saving = true
        ownEvents = (try? await repository.fetchOwnEvents(userId: userId, token: token)) ?? []
        overlapCheckIndex = 0
        await checkNextOverlap(ready)
    }

    /// "Toch plannen" op de dubbele-boeking-alert.
    func proceedPastOverlap() async {
        guard let ready else { return }
        overlapEvent = nil
        saving = true
        overlapCheckIndex += 1
        await checkNextOverlap(ready)
    }

    /// "Aanpassen" op de dubbele-boeking-alert — hele bevestiging afbreken, gesprek blijft staan.
    func cancelOverlap() {
        overlapEvent = nil
        overlapCheckIndex = 0
        ownEvents = []
        saving = false
    }

    private func checkNextOverlap(_ appointments: [ProposedAppointment]) async {
        while overlapCheckIndex < appointments.count {
            let appointment = appointments[overlapCheckIndex]
            let range = AppointmentRange.range(for: appointment)
            if let overlap = EventOverlap.findOverlap(in: ownEvents, start: range.start, end: range.end) {
                overlapEvent = overlap
                saving = false // pauzeert op de alert — geen laadstaat terwijl op de gebruiker wordt gewacht
                return
            }
            overlapCheckIndex += 1
        }
        await createAll(appointments)
    }

    private func createAll(_ appointments: [ProposedAppointment]) async {
        let effectiveAssignees = org != nil ? assignee : []
        do {
            // Hervatten waar het misging: faalde item 2 van 3, dan stond item 1 al
            // op de server en maakte "opnieuw" hem een tweede keer aan.
            for appointment in appointments.dropFirst(createdCount) {
                let payload = AppointmentPayloadBuilder.build(
                    appointment: appointment, ownerId: userId, rawInput: rawInput.isEmpty ? appointment.title : rawInput,
                    org: org, visibility: visibility, viewers: viewers, assignees: effectiveAssignees, reminderMin: reminderMin,
                    label: org != nil ? label : nil, contact: contactId,
                    contactNaam: contactNaam, contactTelefoon: contactTelefoon
                )
                let created = try await repository.createEvent(body: payload.requestBody, token: token)
                if reminderMin > 0 {
                    await reminderService.schedule(eventId: created.id, title: created.title, start: created.start, minutesBefore: reminderMin)
                }
                await deviceCalendarService.sync(appointment)
                createdCount += 1
            }
            let firstDate = AppointmentRange.composeDate(date: appointments[0].date, time: appointments[0].start)
            reset()
            saving = false
            confirmedDate = firstDate
        } catch {
            saving = false
            saveFailedAlert = true
        }
    }
}

import Foundation

/// Gespreks-state voor de AI-planner — geport uit useAiPlanner.ts (chatdeel; het
/// bevestig-blok/confirm() komt in plak 3). Stuurt elke beurt de volledige historie
/// naar de backend en mapt het antwoord naar een chat-thread. De thread overleeft
/// het scherm: hydrate/persist via PlannerThreadStore, gedebouncet (valkuil F).
@MainActor
final class PlannerViewModel: ObservableObject {
    @Published private(set) var thread: [ThreadItem] = []
    @Published private(set) var loading = false
    @Published private(set) var ready: [ProposedAppointment]?

    private let userId: String
    private let token: String
    private let api: PlannerAPI
    private let store: PlannerThreadStore
    private let saveDebounceNanoseconds: UInt64

    private var apiHistory: [ChatTurn] = []
    private var rawInput = ""
    private var idCounter = 0
    private var saveTask: Task<Void, Never>?
    private var hydrated = false

    init(
        userId: String, token: String, api: PlannerAPI = PlannerAPI(),
        store: PlannerThreadStore = PlannerThreadStore(), saveDebounceNanoseconds: UInt64 = 300_000_000
    ) {
        self.userId = userId
        self.token = token
        self.api = api
        self.store = store
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
}

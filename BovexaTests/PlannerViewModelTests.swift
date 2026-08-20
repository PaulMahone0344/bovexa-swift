import Testing
import Foundation
@testable import Bovexa

/// PlannerViewModel — chatflow (versturen → vraag → antwoord → klaar), persist/hydrate
/// en de foutpad (retry). Geport uit useAiPlanner.ts (chatdeel; confirm() is plak 3).
@MainActor
struct PlannerViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
        URLProtocolStub.errorHandler = nil
    }

    private func makeStore() -> PlannerThreadStore {
        let suiteName = "PlannerViewModelTests.\(UUID().uuidString)"
        return PlannerThreadStore(defaults: UserDefaults(suiteName: suiteName)!)
    }

    private func makeViewModel(store: PlannerThreadStore? = nil, debounceNanoseconds: UInt64 = 1_000_000) -> PlannerViewModel {
        PlannerViewModel(
            userId: "u1", token: "tok", api: PlannerAPI(session: URLProtocolStub.makeSession()),
            store: store ?? makeStore(), saveDebounceNanoseconds: debounceNanoseconds
        )
    }

    private func respond(_ json: String) {
        URLProtocolStub.requestHandler = { _ in (200, Data(json.utf8)) }
    }

    @Test func sendTextAddsUserBubbleThenQuestionOnClarification() async {
        respond("""
        {"status":"needs_clarification","message":"Welke dag?","question":"Welke dag bedoel je?","options":["Morgen","Overmorgen"],"appointments":[]}
        """)
        let vm = makeViewModel()
        await vm.sendText("Tandarts inplannen")

        #expect(vm.thread.count == 2)
        #expect(vm.thread[0].kind == .user)
        #expect(vm.thread[0].text == "Tandarts inplannen")
        #expect(vm.thread[1].kind == .question)
        #expect(vm.thread[1].text == "Welke dag bedoel je?")
        #expect(vm.thread[1].options == ["Morgen", "Overmorgen"])
        #expect(vm.ready == nil)
        #expect(vm.loading == false)
    }

    @Test func chooseOptionContinuesConversationToReadyPlan() async {
        var callCount = 0
        URLProtocolStub.requestHandler = { _ in
            callCount += 1
            if callCount == 1 {
                return (200, Data("""
                {"status":"needs_clarification","message":"Welke dag?","question":"Welke dag?","options":["Morgen"],"appointments":[]}
                """.utf8))
            }
            return (200, Data("""
            {"status":"ready","message":"Klaar!","question":null,"options":[],
             "appointments":[{"title":"Tandarts","date":"2026-08-03","start":"09:00","end":"09:30","category":"body"}]}
            """.utf8))
        }
        let vm = makeViewModel()
        await vm.sendText("Tandarts inplannen")
        await vm.chooseOption("Morgen")

        #expect(vm.ready?.count == 1)
        #expect(vm.ready?.first?.title == "Tandarts")
        #expect(vm.thread.last?.kind == .proposal)
        #expect(vm.thread.last?.appointments.first?.title == "Tandarts")
    }

    @Test func newUserMessageRemovesStaleProposalFromThread() async {
        respond("""
        {"status":"ready","message":"Klaar!","question":null,"options":[],
         "appointments":[{"title":"Tandarts","date":"2026-08-03","start":"09:00","end":"09:30","category":"body"}]}
        """)
        let vm = makeViewModel()
        await vm.sendText("Tandarts morgen 9 uur")
        #expect(vm.thread.contains { $0.kind == .proposal })

        respond("""
        {"status":"needs_clarification","message":"Welke dag?","question":"Welke dag?","options":[],"appointments":[]}
        """)
        await vm.sendText("Nieuwe vraag")
        #expect(!vm.thread.contains { $0.kind == .proposal })
        #expect(vm.ready == nil)
    }

    @Test func networkFailureAddsErrorItemAndRetryReusesHistory() async {
        URLProtocolStub.errorHandler = { _ in URLError(.notConnectedToInternet) }
        let vm = makeViewModel()
        await vm.sendText("Tandarts")
        #expect(vm.thread.last?.kind == .error)
        #expect(vm.thread.last?.text == "Geen verbinding met de planner. Controleer je internet en probeer opnieuw.")

        URLProtocolStub.errorHandler = nil
        respond("""
        {"status":"needs_clarification","message":"Welke dag?","question":"Welke dag?","options":[],"appointments":[]}
        """)
        await vm.retry()
        #expect(vm.thread.last?.kind == .question)
        // Fout-item vervangen, niet gestapeld op de user-bubbel.
        #expect(vm.thread.count == 2)
    }

    @Test func emptyOrWhitespaceInputIsIgnored() async {
        let vm = makeViewModel()
        await vm.sendText("   ")
        #expect(vm.thread.isEmpty)
    }

    @Test func resetClearsThreadAndSavedConversation() async {
        respond("""
        {"status":"needs_clarification","message":"?","question":"?","options":[],"appointments":[]}
        """)
        let store = makeStore()
        let vm = makeViewModel(store: store)
        await vm.sendText("Tandarts")
        try? await Task.sleep(nanoseconds: 20_000_000)
        #expect(store.load(userId: "u1") != nil)

        vm.reset()
        #expect(vm.thread.isEmpty)
        #expect(vm.ready == nil)
        #expect(store.load(userId: "u1") == nil)
    }

    /// reset() wiste zichtbaarheid, toewijzing, label en herinnering, maar niet het
    /// contact. Een nieuw gesprek in dezelfde sheet kreeg daardoor stil de klant van
    /// het vorige mee — onzichtbaar, want "Details" staat standaard dicht.
    @Test func resetAlsoClearsTheChosenContact() {
        let vm = makeViewModel(store: makeStore())
        vm.selectContact(AgendaContact(id: "c1", eigenaar: "u1", naam: "Jansen", telefoon: "0612345678", notitie: ""))
        #expect(vm.contactId == "c1")

        vm.reset()

        #expect(vm.contactId == nil)
        #expect(vm.contactNaam == nil)
        #expect(vm.contactTelefoon == nil)
    }

    @Test func persistsConversationAfterDebounceAndHydratesInNewViewModel() async {
        respond("""
        {"status":"ready","message":"Klaar!","question":null,"options":[],
         "appointments":[{"title":"Tandarts","date":"2026-08-03","start":"09:00","end":"09:30","category":"body"}]}
        """)
        let store = makeStore()
        let vm = makeViewModel(store: store)
        await vm.sendText("Tandarts morgen 9 uur")
        try? await Task.sleep(nanoseconds: 20_000_000) // debounce (1ms in test) + marge

        let saved = store.load(userId: "u1")
        #expect(saved != nil)
        #expect(saved?.raw == "Tandarts morgen 9 uur")

        let rehydrated = makeViewModel(store: store)
        rehydrated.hydrate()
        #expect(rehydrated.thread.count == vm.thread.count)
        #expect(rehydrated.ready?.first?.title == "Tandarts") // laatste item was een proposal
    }

    @Test func hydrateDoesNothingWhenNothingWasSaved() {
        let vm = makeViewModel()
        vm.hydrate()
        #expect(vm.thread.isEmpty)
        #expect(vm.ready == nil)
    }
}

import Testing
import Foundation
@testable import Bovexa

@MainActor
struct DagtakenViewModelTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "bovexa-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeViewModel() -> DagtakenViewModel {
        URLProtocolStub.requestHandler = nil
        return DagtakenViewModel(
            planningStore: PlanningNoteStore(defaults: makeDefaults()),
            taskRepository: TaskRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            eventRepository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession()))
        )
    }

    private func bodyData(from request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }

    // MARK: - composer-tekst → juiste taak (lokaal)

    @Test func submitWithoutOrgCreatesLocalNote() async {
        let vm = makeViewModel()
        vm.draft = "Bellen met klant\nOver de offerte"
        await vm.submit(userId: "u1", org: nil, token: "tok")
        #expect(vm.openNotes.count == 1)
        #expect(vm.openNotes.first?.title == "Bellen met klant")
        #expect(vm.openNotes.first?.body == "Over de offerte")
        #expect(vm.draft == "")
    }

    @Test func submitWithOrgButPrivateVisibilityStillCreatesLocalNote() async {
        let vm = makeViewModel()
        vm.draft = "Privétaak"
        vm.visibility = .private
        await vm.submit(userId: "u1", org: "org1", token: "tok")
        #expect(vm.openNotes.count == 1)
        #expect(vm.openNotes.first?.title == "Privétaak")
    }

    @Test func submitWithEmptyDraftDoesNothing() async {
        let vm = makeViewModel()
        vm.draft = "   "
        await vm.submit(userId: "u1", org: nil, token: "tok")
        #expect(vm.openNotes.isEmpty)
    }

    // MARK: - composer-tekst → juiste taak (team)

    @Test func submitWithOrgAndCompanyVisibilityCreatesTeamTaskInsteadOfLocalNote() async {
        let vm = makeViewModel()
        URLProtocolStub.requestHandler = { request in
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["title"] as? String == "Voorraad tellen")
            #expect(body["notes"] as? String == "Voor vrijdag")
            #expect(body["visibility"] as? String == "company")
            let json = """
            {"id":"t1","owner":"u1","org":"org1","title":"Voorraad tellen","notes":"Voor vrijdag","status":"open",
             "visibility":"company","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        vm.draft = "Voorraad tellen\nVoor vrijdag"
        vm.visibility = .company
        await vm.submit(userId: "u1", org: "org1", token: "tok")
        #expect(vm.openNotes.isEmpty)
        #expect(vm.draft == "")
        #expect(vm.visibility == .private)
        #expect(vm.createFailedAlert == false)
    }

    @Test func submitTeamTaskFailureShowsAlertAndKeepsDraft() async {
        let vm = makeViewModel()
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"data":{},"message":"Kon niet opslaan.","status":400}
            """.data(using: .utf8)!
            return (400, json)
        }
        vm.draft = "Voorraad tellen"
        vm.visibility = .company
        await vm.submit(userId: "u1", org: "org1", token: "tok")
        #expect(vm.createFailedAlert == true)
        #expect(vm.draft == "Voorraad tellen")
    }

    // MARK: - bewerken vervangt i.p.v. toe te voegen

    @Test func editingReplacesExistingNoteInsteadOfAddingNew() async {
        let vm = makeViewModel()
        vm.draft = "Origineel"
        await vm.submit(userId: "u1", org: nil, token: "tok")
        let original = vm.openNotes.first!

        vm.startEdit(original)
        #expect(vm.draft == "Origineel")
        vm.draft = "Aangepast"
        await vm.submit(userId: "u1", org: nil, token: "tok")

        #expect(vm.openNotes.count == 1)
        #expect(vm.openNotes.first?.id == original.id)
        #expect(vm.openNotes.first?.title == "Aangepast")
        #expect(vm.isEditing == false)
    }

    // MARK: - annuleren laat de lijst ongemoeid

    @Test func cancelEditLeavesListUnchanged() async {
        let vm = makeViewModel()
        vm.draft = "Blijft zo"
        await vm.submit(userId: "u1", org: nil, token: "tok")
        let before = vm.openNotes

        vm.startEdit(before.first!)
        vm.draft = "Zou veranderen"
        vm.cancelEdit()

        #expect(vm.openNotes.map(\.title) == before.map(\.title))
        #expect(vm.isEditing == false)
        #expect(vm.draft == "")
    }

    // MARK: - archiveren

    @Test func archiveMovesNoteOutOfOpenNotes() async {
        let vm = makeViewModel()
        vm.draft = "Te archiveren"
        await vm.submit(userId: "u1", org: nil, token: "tok")
        let note = vm.openNotes.first!

        vm.archive(note.id)

        #expect(vm.openNotes.isEmpty)
        #expect(vm.archivedNotes.map(\.id) == [note.id])
    }

    // MARK: - loadOrgInfo

    @Test func loadOrgInfoPrimesOrgNameAndMemberColors() async {
        let vm = makeViewModel()
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"items":[{"id":"m1","userId":"u1","naam":"Ibrahim","email":"i@bovexa.nl","avatar":""}],
             "org":{"id":"org1","name":"Bovexa","logo":""}}
            """.data(using: .utf8)!
            return (200, json)
        }
        await vm.loadOrgInfo(token: "tok")
        #expect(vm.orgName == "Bovexa")
        #expect(vm.memberColors.firstName(for: "u1") == "Ibrahim")
    }

    // MARK: - restore

    @Test func restoreMovesNoteBackToOpenNotes() async {
        let vm = makeViewModel()
        vm.draft = "Terug uit archief"
        await vm.submit(userId: "u1", org: nil, token: "tok")
        let note = vm.openNotes.first!
        vm.archive(note.id)

        vm.restore(note.id)

        #expect(vm.archivedNotes.isEmpty)
        #expect(vm.openNotes.map(\.id) == [note.id])
    }

    // MARK: - twee-tik-bevestiging (valkuil G)

    @Test func requestDeleteMarksThenDeletesOnSecondTapWithinWindow() async {
        let vm = makeViewModel()
        vm.draft = "Te wissen"
        await vm.submit(userId: "u1", org: nil, token: "tok")
        let note = vm.openNotes.first!
        vm.archive(note.id)
        let archived = vm.archivedNotes.first!

        vm.requestDeleteLocalNote(archived.id)
        #expect(vm.confirmDeleteId == archived.id)
        #expect(vm.archivedNotes.count == 1)

        vm.requestDeleteLocalNote(archived.id)
        #expect(vm.confirmDeleteId == nil)
        #expect(vm.archivedNotes.isEmpty)
    }

    @Test func requestDeleteConfirmationExpiresAfterTimeout() async throws {
        let vm = DagtakenViewModel(
            planningStore: PlanningNoteStore(defaults: makeDefaults()),
            taskRepository: TaskRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            eventRepository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            confirmDeleteTimeout: .milliseconds(20)
        )
        vm.draft = "Te wissen"
        await vm.submit(userId: "u1", org: nil, token: "tok")
        let note = vm.openNotes.first!
        vm.archive(note.id)
        let archived = vm.archivedNotes.first!

        vm.requestDeleteLocalNote(archived.id)
        #expect(vm.confirmDeleteId == archived.id)

        try await Task.sleep(for: .milliseconds(80))

        #expect(vm.confirmDeleteId == nil)
        #expect(vm.archivedNotes.map(\.id) == [archived.id])

        // Na de vervaltijd telt een volgende tik weer als de ÉÉRSTE tik.
        vm.requestDeleteLocalNote(archived.id)
        #expect(vm.confirmDeleteId == archived.id)
        #expect(vm.archivedNotes.map(\.id) == [archived.id])
    }

    // MARK: - loadTeamTasks (valkuil C + D)

    @Test func loadTeamTasksWithoutOrgSkipsNetworkAndClearsList() async {
        let vm = makeViewModel()
        URLProtocolStub.requestHandler = { _ in
            Issue.record("mag geen netwerkverzoek doen zonder org")
            return (500, Data())
        }
        await vm.loadTeamTasks(org: nil, token: "tok")
        #expect(vm.teamTasks.isEmpty)
    }

    @Test func loadTeamTasksWithOrgPopulatesList() async {
        let vm = makeViewModel()
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"items":[{"id":"t1","owner":"u1","org":"org1","title":"Taak","notes":"","status":"open",
             "visibility":"company","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}],
             "page":1,"perPage":200,"totalItems":1,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        await vm.loadTeamTasks(org: "org1", token: "tok")
        #expect(vm.teamTasks.map(\.id) == ["t1"])
    }

    @Test func submitTeamTaskPrependsToTeamTasksImmediately() async {
        let vm = makeViewModel()
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"id":"t1","owner":"u1","org":"org1","title":"Nieuw","notes":"","status":"open",
             "visibility":"company","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        vm.draft = "Nieuw"
        vm.visibility = .company
        await vm.submit(userId: "u1", org: "org1", token: "tok")
        #expect(vm.teamTasks.map(\.id) == ["t1"])
    }

    // MARK: - toggleTeamTask (valkuil E + F)

    private func makeTask(
        id: String = "t1", owner: String = "u1", status: TaskStatus = .open,
        visibility: TaskVisibility = .company
    ) -> AgendaTask {
        AgendaTask(
            id: id, owner: owner, org: "org1", title: "Taak", notes: nil, status: status,
            visibility: visibility, viewers: [], created: Date(timeIntervalSince1970: 0), updated: Date(timeIntervalSince1970: 0)
        )
    }

    /// Sinds 27 juli mag een collega een gedeelde bedrijfstaak wél afvinken: wie hem
    /// doet, vinkt hem af. Wissen blijft van de eigenaar.
    @Test func toggleTeamTaskOnColleagueCompanyTaskIsAllowed() async {
        let vm = makeViewModel()
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"id":"t1","owner":"u2","org":"org1","title":"Taak","notes":"","status":"klaar",
             "visibility":"company","viewers":[],"created":"2026-07-24 09:00:00.000Z",
             "updated":"2026-07-24 09:00:00.000Z","completed_at":"2026-07-27 12:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }

        await vm.toggleTeamTask(makeTask(owner: "u2"), userId: "u1", token: "tok")

        // De taak zat nog niet in de lijst van dit viewmodel; het gaat hier om of het
        // verzoek überhaupt de deur uit mocht (de stub records geen Issue meer).
        #expect(!vm.deleteTeamTaskFailedAlert)
    }

    /// Een privétaak van een collega blijft onaanraakbaar — die hoort er sowieso niet
    /// te staan, en als hij er staat gaat er geen verzoek uit.
    @Test func toggleTeamTaskOnColleaguePrivateTaskDoesNothing() async {
        let vm = makeViewModel()
        URLProtocolStub.requestHandler = { _ in
            Issue.record("mag niet afvinken bij een privétaak van een ander")
            return (500, Data())
        }

        await vm.toggleTeamTask(makeTask(owner: "u2", visibility: .private), userId: "u1", token: "tok")

        #expect(vm.teamTasks.isEmpty)
    }

    @Test func toggleTeamTaskOnOwnTaskFlipsStatusOptimisticallyThenConfirms() async {
        let vm = makeViewModel()
        // Seed via een gemockte fetch, i.p.v. rechtstreeks state te injecteren.
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"items":[{"id":"t1","owner":"u1","org":"org1","title":"Taak","notes":"","status":"open",
             "visibility":"company","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}],
             "page":1,"perPage":200,"totalItems":1,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        await vm.loadTeamTasks(org: "org1", token: "tok")
        let task = vm.teamTasks.first!

        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "PATCH")
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["status"] as? String == "klaar")
            let json = """
            {"id":"t1","owner":"u1","org":"org1","title":"Taak","notes":"","status":"klaar",
             "visibility":"company","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        await vm.toggleTeamTask(task, userId: "u1", token: "tok")
        #expect(vm.teamTasks.first?.status == .klaar)
    }

    @Test func toggleTeamTaskSetsCompletedAtAndUntogglingClearsIt() async {
        let vm = makeViewModel()
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"items":[{"id":"t1","owner":"u1","org":"org1","title":"Taak","notes":"","status":"open",
             "visibility":"company","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}],
             "page":1,"perPage":200,"totalItems":1,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        await vm.loadTeamTasks(org: "org1", token: "tok")
        let task = vm.teamTasks.first!

        URLProtocolStub.requestHandler = { request in
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            let json = """
            {"id":"t1","owner":"u1","org":"org1","title":"Taak","notes":"","status":"klaar","completed_at":"\(body["completed_at"] as? String ?? "")",
             "visibility":"company","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        await vm.toggleTeamTask(task, userId: "u1", token: "tok")
        #expect(vm.teamTasks.first?.completedAt != nil)

        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"id":"t1","owner":"u1","org":"org1","title":"Taak","notes":"","status":"open",
             "visibility":"company","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        await vm.toggleTeamTask(vm.teamTasks.first!, userId: "u1", token: "tok")
        #expect(vm.teamTasks.first?.completedAt == nil)
    }

    @Test func toggleTeamTaskRollsBackOnServerFailure() async {
        let vm = makeViewModel()
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"items":[{"id":"t1","owner":"u1","org":"org1","title":"Taak","notes":"","status":"open",
             "visibility":"company","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}],
             "page":1,"perPage":200,"totalItems":1,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        await vm.loadTeamTasks(org: "org1", token: "tok")
        let task = vm.teamTasks.first!

        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"data":{},"message":"Mislukt.","status":400}
            """.data(using: .utf8)!
            return (400, json)
        }
        await vm.toggleTeamTask(task, userId: "u1", token: "tok")
        #expect(vm.teamTasks.first?.status == .open)
    }

    // MARK: - deleteTeamTask (valkuil E)

    @Test func deleteTeamTaskOnColleagueTaskDoesNothing() async {
        let vm = makeViewModel()
        URLProtocolStub.requestHandler = { _ in
            Issue.record("mag niet wissen bij andermans taak")
            return (500, Data())
        }
        let colleagueTask = makeTask(owner: "u2")
        await vm.deleteTeamTask(colleagueTask, userId: "u1", token: "tok")
        #expect(vm.deleteTeamTaskFailedAlert == false)
    }

    @Test func deleteTeamTaskOnOwnTaskRemovesItFromList() async {
        let vm = makeViewModel()
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"items":[{"id":"t1","owner":"u1","org":"org1","title":"Taak","notes":"","status":"open",
             "visibility":"company","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}],
             "page":1,"perPage":200,"totalItems":1,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        await vm.loadTeamTasks(org: "org1", token: "tok")
        let task = vm.teamTasks.first!

        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "DELETE")
            return (204, Data())
        }
        await vm.deleteTeamTask(task, userId: "u1", token: "tok")
        #expect(vm.teamTasks.isEmpty)
    }

    @Test func deleteTeamTaskFailureShowsAlertAndKeepsTask() async {
        let vm = makeViewModel()
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"items":[{"id":"t1","owner":"u1","org":"org1","title":"Taak","notes":"","status":"open",
             "visibility":"company","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}],
             "page":1,"perPage":200,"totalItems":1,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        await vm.loadTeamTasks(org: "org1", token: "tok")

        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"data":{},"message":"Mislukt.","status":400}
            """.data(using: .utf8)!
            return (400, json)
        }
        await vm.deleteTeamTask(vm.teamTasks.first!, userId: "u1", token: "tok")
        #expect(vm.deleteTeamTaskFailedAlert == true)
        #expect(vm.teamTasks.count == 1)
    }
}

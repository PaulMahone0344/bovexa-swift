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
}

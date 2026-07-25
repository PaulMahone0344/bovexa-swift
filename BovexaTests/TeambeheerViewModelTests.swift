import Testing
import Foundation
@testable import Bovexa

@MainActor
struct TeambeheerViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeViewModel() -> TeambeheerViewModel {
        TeambeheerViewModel(repository: CompanyRepository(client: PBClient(session: URLProtocolStub.makeSession())))
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

    private func bodyJSON(from request: URLRequest) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: bodyData(from: request)) as? [String: Any]) ?? [:]
    }

    // MARK: - Standaardduur-stepper

    @Test func decrementRespectsLowerBoundOfFive() async {
        URLProtocolStub.requestHandler = { _ in
            (200, """
            {"items":[],"seats_max":3,"plan":"free","join_code":"X","org":{"id":"org1","name":"Bovexa BV","logo":"","ics_token":"","address":"","phone":"","email":"","opening_hours":null,"timezone":"","default_duration_min":10}}
            """.data(using: .utf8)!)
        }
        let vm = makeViewModel()
        await vm.load(token: "tok")
        #expect(vm.defaultDurationMin == 10)
        vm.decrementDuration() // -> max(5, -5) == 5
        #expect(vm.defaultDurationMin == 5)
        vm.decrementDuration() // blijft op de ondergrens
        #expect(vm.defaultDurationMin == 5)
    }

    @Test func incrementAndDecrementStepByFifteen() {
        let vm = makeViewModel()
        vm.incrementDuration()
        #expect(vm.defaultDurationMin == 45)
        vm.decrementDuration()
        #expect(vm.defaultDurationMin == 30)
    }

    // MARK: - Openingstijden

    @Test func emptyOpenAndCloseMeansClosed() {
        let vm = makeViewModel()
        vm.setDayHours(\.mon, open: "09:00", close: "17:00")
        #expect(vm.openingHours.mon?.open == "09:00")
        vm.setDayHours(\.mon, open: "", close: "")
        #expect(vm.openingHours.mon == nil)
    }

    @Test func halfFilledDayIsDroppedOnSave() async {
        URLProtocolStub.requestHandler = { request in
            let hours = self.bodyJSON(from: request)["opening_hours"] as? [String: Any]
            #expect(hours?["mon"] == nil) // enkel 'open' ingevuld telt als gesloten
            return (200, """
            {"id":"org1","address":"","phone":"","email":"","opening_hours":null,"timezone":"Europe/Amsterdam","default_duration_min":30}
            """.data(using: .utf8)!)
        }
        let vm = makeViewModel()
        vm.openingHours.mon = DayHours(open: "09:00", close: "")
        await vm.saveProfile(token: "tok")
    }

    // MARK: - Payload-vorm profiel-route

    @Test func saveProfileSendsExpectedFields() async {
        URLProtocolStub.requestHandler = { request in
            let body = self.bodyJSON(from: request)
            #expect(body["address"] as? String == "Hoofdstraat 1")
            #expect(body["timezone"] as? String == "Europe/Amsterdam")
            #expect(body["default_duration_min"] as? Int == 45)
            let hours = body["opening_hours"] as? [String: Any]
            #expect((hours?["tue"] as? [String: Any])?["open"] as? String == "09:00")
            return (200, """
            {"id":"org1","address":"Hoofdstraat 1","phone":"","email":"","opening_hours":{"tue":{"open":"09:00","close":"17:00"}},"timezone":"Europe/Amsterdam","default_duration_min":45}
            """.data(using: .utf8)!)
        }
        let vm = makeViewModel()
        vm.address = "Hoofdstraat 1"
        vm.timezone = "Europe/Amsterdam"
        vm.incrementDuration() // 30 -> 45
        vm.setDayHours(\.tue, open: "09:00", close: "17:00")
        await vm.saveProfile(token: "tok")
        #expect(vm.defaultDurationMin == 45)
        #expect(vm.errorMessage == nil)
    }

    // MARK: - Uitnodigen

    @Test func sendInviteClearsFieldAndSetsConfirmation() async {
        URLProtocolStub.requestHandler = { request in
            #expect(self.bodyJSON(from: request)["email"] as? String == "collega@voorbeeld.nl")
            return (200, """
            {"sent":true,"email":"collega@voorbeeld.nl"}
            """.data(using: .utf8)!)
        }
        let vm = makeViewModel()
        vm.inviteEmail = "collega@voorbeeld.nl"
        await vm.sendInvite(token: "tok")
        #expect(vm.inviteEmail.isEmpty)
        #expect(vm.inviteSentMessage == "Uitnodiging gestuurd naar collega@voorbeeld.nl.")
    }

    @Test func rotateCodeUpdatesJoinCode() async {
        URLProtocolStub.requestHandler = { _ in
            (200, """
            {"join_code":"BOVEXA-9K2L"}
            """.data(using: .utf8)!)
        }
        let vm = makeViewModel()
        await vm.rotateCode(token: "tok")
        #expect(vm.joinCode == "BOVEXA-9K2L")
        #expect(!vm.rotating)
    }

    // MARK: - Laden

    @Test func loadPopulatesSeatsAndActiveCount() async {
        URLProtocolStub.requestHandler = { _ in
            (200, """
            {"items":[
              {"id":"m1","userId":"u1","naam":"Anna","email":"a@x.nl","avatar":"","role":"admin","status":"active","isOwner":true,"magMaken":true,"magWijzigen":true,"magVerwijderen":true,"magKlantZien":true,"magAgendaAnderenZien":true},
              {"id":"m2","userId":"u2","naam":"","email":"b@x.nl","avatar":"","role":"member","status":"invited","isOwner":false,"magMaken":false,"magWijzigen":false,"magVerwijderen":false,"magKlantZien":false,"magAgendaAnderenZien":false}
            ],"seats_max":3,"plan":"free","join_code":"BOVEXA-7F3K","org":{"id":"org1","name":"Bovexa BV","logo":"","ics_token":"","address":"","phone":"","email":"","opening_hours":null,"timezone":"","default_duration_min":0}}
            """.data(using: .utf8)!)
        }
        let vm = makeViewModel()
        await vm.load(token: "tok")
        #expect(vm.seatsMax == 3)
        #expect(vm.activeMemberCount == 1) // alleen 'active', niet 'invited'
        #expect(!vm.full)
        #expect(vm.defaultDurationMin == 30) // 0 uit de server valt terug op 30
    }
}

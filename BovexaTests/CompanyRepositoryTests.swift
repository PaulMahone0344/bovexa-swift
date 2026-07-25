import Testing
import Foundation
@testable import Bovexa

struct CompanyRepositoryTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeRepository() -> CompanyRepository {
        CompanyRepository(client: PBClient(session: URLProtocolStub.makeSession()))
    }

    /// URLSession verplaatst httpBody vaak stilletjes naar httpBodyStream vóórdat een
    /// URLProtocol-subclass het verzoek ziet — request.httpBody is dan nil.
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
        let data = bodyData(from: request)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - Payload-vorm per route

    @Test func createCompanySendsName() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.url?.path == "/api/agenda/company/create")
            #expect(self.bodyJSON(from: request)["name"] as? String == "Bovexa BV")
            let json = """
            {"id":"org1","name":"Bovexa BV","join_code":"BOVEXA-7F3K","plan":"free","seats_max":3,"role":"admin"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let info = try await makeRepository().createCompany(name: "Bovexa BV", token: "tok")
        #expect(info.id == "org1")
        #expect(info.joinCode == "BOVEXA-7F3K")
        #expect(info.seatsMax == 3)
        #expect(info.role == .admin)
    }

    @Test func joinCompanySendsCode() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.url?.path == "/api/agenda/company/join")
            #expect(self.bodyJSON(from: request)["code"] as? String == "BOVEXA-7F3K")
            let json = """
            {"id":"org1","name":"Bovexa BV","join_code":"BOVEXA-7F3K","plan":"free","seats_max":3,"role":"member"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let info = try await makeRepository().joinCompany(code: "BOVEXA-7F3K", token: "tok")
        #expect(info.role == .member)
    }

    @Test func listMembersDecodesCamelCaseMemberFieldsAndSnakeCaseOrg() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.url?.path == "/api/agenda/company/members")
            let json = """
            {
              "items": [
                {"id":"m1","userId":"u1","naam":"Anna","email":"anna@x.nl","avatar":"","role":"admin","status":"active","isOwner":true,"magMaken":true,"magWijzigen":false,"magVerwijderen":false,"magKlantZien":true,"magAgendaAnderenZien":true}
              ],
              "seats_max": 3,
              "plan": "free",
              "join_code": "BOVEXA-7F3K",
              "org": {"id":"org1","name":"Bovexa BV","logo":"","ics_token":"tok123","address":"","phone":"","email":"","opening_hours":null,"timezone":"Europe/Amsterdam","default_duration_min":30}
            }
            """.data(using: .utf8)!
            return (200, json)
        }
        let response = try await makeRepository().listMembers(token: "tok")
        #expect(response.items.count == 1)
        #expect(response.items[0].isOwner)
        #expect(response.seatsMax == 3)
        #expect(response.org?.icsToken == "tok123")
        #expect(response.org?.defaultDurationMin == 30)
    }

    @Test func setMemberRoleSendsMemberIdAndRole() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = self.bodyJSON(from: request)
            #expect(body["memberId"] as? String == "m1")
            #expect(body["role"] as? String == "admin")
            return (200, """
            {"id":"m1","role":"admin"}
            """.data(using: .utf8)!)
        }
        let result = try await makeRepository().setMemberRole(memberId: "m1", role: .admin, token: "tok")
        #expect(result.role == .admin)
    }

    @Test func setMemberPermissionsSendsSingleToggle() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = self.bodyJSON(from: request)
            #expect(body["memberId"] as? String == "m1")
            #expect(body["mag_wijzigen"] as? Bool == true)
            return (200, """
            {"id":"m1","mag_maken":true,"mag_wijzigen":true,"mag_verwijderen":false,"mag_klant_zien":true,"mag_agenda_anderen_zien":true}
            """.data(using: .utf8)!)
        }
        let result = try await makeRepository().setMemberPermissions(memberId: "m1", key: "mag_wijzigen", value: true, token: "tok")
        #expect(result.magWijzigen)
    }

    @Test func removeMemberSendsMemberId() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(self.bodyJSON(from: request)["memberId"] as? String == "m1")
            return (200, """
            {"id":"m1","removed":true}
            """.data(using: .utf8)!)
        }
        let result = try await makeRepository().removeMember(memberId: "m1", token: "tok")
        #expect(result.removed)
    }

    @Test func rotateCodeReturnsNewCode() async throws {
        URLProtocolStub.requestHandler = { _ in
            (200, """
            {"join_code":"BOVEXA-9K2L"}
            """.data(using: .utf8)!)
        }
        let result = try await makeRepository().rotateCode(token: "tok")
        #expect(result.joinCode == "BOVEXA-9K2L")
    }

    @Test func updateProfileOnlySendsProvidedFields() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = self.bodyJSON(from: request)
            #expect(body["address"] as? String == "Hoofdstraat 1")
            #expect(body["phone"] == nil)
            #expect(body["default_duration_min"] as? Int == 45)
            let hours = body["opening_hours"] as? [String: Any]
            #expect((hours?["mon"] as? [String: Any])?["open"] as? String == "09:00")
            return (200, """
            {"id":"org1","address":"Hoofdstraat 1","phone":"","email":"","opening_hours":null,"timezone":"Europe/Amsterdam","default_duration_min":45}
            """.data(using: .utf8)!)
        }
        var update = CompanyProfileUpdate()
        update.address = "Hoofdstraat 1"
        update.defaultDurationMin = 45
        var hours = OpeningHours()
        hours.mon = DayHours(open: "09:00", close: "17:00")
        update.openingHours = hours
        let result = try await makeRepository().updateProfile(update, token: "tok")
        #expect(result.defaultDurationMin == 45)
    }

    @Test func sendInviteSendsEmail() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(self.bodyJSON(from: request)["email"] as? String == "collega@voorbeeld.nl")
            return (200, """
            {"sent":true,"email":"collega@voorbeeld.nl"}
            """.data(using: .utf8)!)
        }
        let result = try await makeRepository().sendInvite(email: "collega@voorbeeld.nl", token: "tok")
        #expect(result.sent)
    }

    @Test func removeLogoSendsRemoveFlag() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(self.bodyJSON(from: request)["remove"] as? Bool == true)
            return (200, """
            {"id":"org1","logo":""}
            """.data(using: .utf8)!)
        }
        let result = try await makeRepository().removeLogo(token: "tok")
        #expect(result.logo.isEmpty)
    }

    // MARK: - Foutvertaling

    @Test func serverMessagePassesThroughUnchanged() async throws {
        URLProtocolStub.requestHandler = { _ in
            (400, """
            {"message":"Bedrijf zit vol."}
            """.data(using: .utf8)!)
        }
        do {
            _ = try await makeRepository().joinCompany(code: "X", token: "tok")
            Issue.record("verwachtte een fout")
        } catch let error as CompanyError {
            #expect(error.message == "Bedrijf zit vol.")
        }
    }

    @Test func rateLimitMessagePassesThroughUnchanged() async throws {
        URLProtocolStub.requestHandler = { _ in
            (429, """
            {"message":"Te veel pogingen. Probeer over een minuut opnieuw."}
            """.data(using: .utf8)!)
        }
        do {
            _ = try await makeRepository().joinCompany(code: "X", token: "tok")
            Issue.record("verwachtte een fout")
        } catch let error as CompanyError {
            #expect(error.message == "Te veel pogingen. Probeer over een minuut opnieuw.")
        }
    }

    @Test func networkErrorUsesDutchFallback() async throws {
        URLProtocolStub.errorHandler = { _ in URLError(.notConnectedToInternet) }
        do {
            _ = try await makeRepository().joinCompany(code: "X", token: "tok")
            Issue.record("verwachtte een fout")
        } catch let error as CompanyError {
            #expect(error.message == "Geen verbinding. Controleer je internet en probeer opnieuw.")
        }
        URLProtocolStub.errorHandler = nil
    }

    @Test func emptyServerMessageFallsBackToRouteSpecificText() async throws {
        URLProtocolStub.requestHandler = { _ in
            (400, """
            {"message":""}
            """.data(using: .utf8)!)
        }
        do {
            _ = try await makeRepository().createCompany(name: "X", token: "tok")
            Issue.record("verwachtte een fout")
        } catch let error as CompanyError {
            #expect(error.message == "Bedrijf aanmaken mislukt. Probeer opnieuw.")
        }
    }
}

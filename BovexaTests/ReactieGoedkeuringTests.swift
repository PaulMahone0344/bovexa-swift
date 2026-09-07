import Testing
import Foundation
@testable import Bovexa

/// De velden `reactie` en `goedkeuring` op agenda_events (punten 18 en 19,
/// server 7 sep 2026): het antwoord van de beheerder mag de reden van de
/// medewerker in `notes` niet meer overschrijven.
struct ReactieGoedkeuringTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeRepository() -> EventRepository {
        EventRepository(client: PBClient(session: URLProtocolStub.makeSession()))
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

    private func event() -> AgendaEvent {
        AgendaEvent(
            id: "rec1", owner: "owner", calendar: nil, category: .afwezig, title: "Afwezig",
            start: Date(), end: nil, allDay: true, recurrence: nil, location: nil,
            notes: "tandarts", klantNaam: nil, assigneeStatus: ["u1": "pending"],
            seriesId: nil, occurrenceDate: nil
        )
    }

    // MARK: - Decoderen

    private func decode(_ json: String) throws -> AgendaEvent {
        try JSONDecoder().decode(AgendaEvent.self, from: json.data(using: .utf8)!)
    }

    private let basis = """
    "id":"ev1","owner":"u1","title":"Afwezig","start":"2026-07-24 09:00:00.000Z","all_day":true
    """

    @Test func reactieAndGoedkeuringAreDecoded() throws {
        let e = try decode("{\(basis),\"notes\":\"tandarts\",\"reactie\":\"prima\",\"goedkeuring\":\"akkoord\"}")
        #expect(e.notes == "tandarts")
        #expect(e.reactie == "prima")
        #expect(e.goedkeuring == "akkoord")
    }

    /// Beide velden mogen ontbreken — alles van vóór 7 sep 2026 heeft ze niet.
    @Test func missingFieldsDecodeAsNil() throws {
        let e = try decode("{\(basis)}")
        #expect(e.reactie == nil)
        #expect(e.goedkeuring == nil)
    }

    @Test func unexpectedTypesDoNotCrash() throws {
        let e = try decode("{\(basis),\"reactie\":42,\"goedkeuring\":[\"open\"]}")
        #expect(e.reactie == nil)
        #expect(e.goedkeuring == nil)
    }

    @Test func occurrenceCopyKeepsBothFields() throws {
        let e = try decode("{\(basis),\"reactie\":\"prima\",\"goedkeuring\":\"akkoord\"}")
        let kopie = e.withOccurrence(id: "ev1:2026-07-25", start: e.start, end: nil, seriesId: "ev1", occurrenceDate: "2026-07-25")
        #expect(kopie.reactie == "prima")
        #expect(kopie.goedkeuring == "akkoord")
    }

    // MARK: - Antwoord van de beheerder

    @Test func answerGoesToReactieAndNeverToNotes() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["reactie"] as? String == "kan niet, te weinig mensen")
            // De reden van de medewerker blijft staan.
            #expect(body["notes"] == nil)
            #expect(body["goedkeuring"] as? String == "geweigerd")
            let json = """
            {"id":"rec1","owner":"owner","title":"Afwezig","start":"2026-08-03 09:00:00.000Z","all_day":true}
            """.data(using: .utf8)!
            return (200, json)
        }
        _ = try await makeRepository().respondToAssignment(
            event: event(), userId: "u1", status: "declined", token: "tok",
            notitie: "kan niet, te weinig mensen"
        )
    }

    @Test func acceptingWithoutANoteStillSetsGoedkeuring() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["reactie"] == nil)
            #expect(body["goedkeuring"] as? String == "akkoord")
            let json = """
            {"id":"rec1","owner":"owner","title":"Afwezig","start":"2026-08-03 09:00:00.000Z","all_day":true}
            """.data(using: .utf8)!
            return (200, json)
        }
        _ = try await makeRepository().respondToAssignment(
            event: event(), userId: "u1", status: "accepted", token: "tok"
        )
    }

    @Test func whitespaceOnlyNoteIsNotWritten() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["reactie"] == nil)
            let json = """
            {"id":"rec1","owner":"owner","title":"Afwezig","start":"2026-08-03 09:00:00.000Z","all_day":true}
            """.data(using: .utf8)!
            return (200, json)
        }
        _ = try await makeRepository().respondToAssignment(
            event: event(), userId: "u1", status: "accepted", token: "tok", notitie: "   "
        )
    }

    @Test func onlyARealAnswerMapsToAGoedkeuringValue() {
        #expect(AanvraagStatus.goedkeuring(voor: "accepted") == "akkoord")
        #expect(AanvraagStatus.goedkeuring(voor: "declined") == "geweigerd")
        #expect(AanvraagStatus.goedkeuring(voor: "pending") == nil)
    }

    // MARK: - Doorgeven door de medewerker

    @Test func absenceWithAnApproverStartsAtOpen() {
        let payload = AfwezigCreatePayload(
            owner: "u1", org: "org1", title: "Afwezig", calendar: "work", visibility: "people",
            start: Date(), rawInput: "afwezig: tandarts", viewers: ["u1", "beheer"],
            assignee: ["beheer"], assigneeStatus: ["beheer": "pending"], notes: "tandarts"
        )
        let body = payload.requestBody
        #expect(body["goedkeuring"] as? String == "open")
        // De opmerking van de medewerker blijft in notes staan.
        #expect(body["notes"] as? String == "tandarts")
        #expect(body["reactie"] == nil)
    }

    /// Zonder beheerder valt er niets goed te keuren; dan hoort het veld weg te
    /// blijven in plaats van eeuwig op "open" te staan.
    @Test func absenceWithoutAnApproverOmitsGoedkeuring() {
        let payload = AfwezigCreatePayload(
            owner: "u1", org: "", title: "Afwezig", calendar: "private", visibility: "private",
            start: Date(), rawInput: "afwezig: tandarts"
        )
        #expect(payload.requestBody["goedkeuring"] == nil)
    }
}

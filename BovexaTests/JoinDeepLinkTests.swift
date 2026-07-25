import Testing
import Foundation
@testable import Bovexa

struct JoinDeepLinkTests {
    @Test func extractsCodeFromValidLink() {
        let url = URL(string: "bovexaflow://join?code=BOVEXA-7F3K")!
        #expect(JoinDeepLink.code(from: url) == "BOVEXA-7F3K")
    }

    @Test func rejectsWrongScheme() {
        let url = URL(string: "https://join?code=BOVEXA-7F3K")!
        #expect(JoinDeepLink.code(from: url) == nil)
    }

    @Test func rejectsWrongHost() {
        let url = URL(string: "bovexaflow://other?code=BOVEXA-7F3K")!
        #expect(JoinDeepLink.code(from: url) == nil)
    }

    @Test func rejectsMissingCode() {
        let url = URL(string: "bovexaflow://join")!
        #expect(JoinDeepLink.code(from: url) == nil)
    }

    @Test func rejectsEmptyCode() {
        let url = URL(string: "bovexaflow://join?code=")!
        #expect(JoinDeepLink.code(from: url) == nil)
    }
}

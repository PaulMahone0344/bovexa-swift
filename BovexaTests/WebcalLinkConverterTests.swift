import Testing
import Foundation
@testable import Bovexa

struct WebcalLinkConverterTests {
    @Test func httpsLinkIsConvertedToWebcal() {
        let url = WebcalLinkConverter.convert("https://example.com/agenda.ics")
        #expect(url?.absoluteString == "webcal://example.com/agenda.ics")
    }

    @Test func httpLinkIsConvertedToWebcal() {
        let url = WebcalLinkConverter.convert("http://example.com/agenda.ics")
        #expect(url?.scheme == "webcal")
    }

    @Test func webcalLinkIsAcceptedUnchanged() {
        let url = WebcalLinkConverter.convert("webcal://example.com/agenda.ics")
        #expect(url?.absoluteString == "webcal://example.com/agenda.ics")
    }

    @Test func linkWithQueryStringIsPreserved() {
        let url = WebcalLinkConverter.convert("https://example.com/feed?token=abc123")
        #expect(url?.absoluteString == "webcal://example.com/feed?token=abc123")
    }

    @Test func whitespaceIsTrimmedBeforeParsing() {
        let url = WebcalLinkConverter.convert("  https://example.com/agenda.ics  ")
        #expect(url?.scheme == "webcal")
    }

    @Test func nonsenseInputIsRejected() {
        #expect(WebcalLinkConverter.convert("dit is geen link") == nil)
    }

    @Test func unsupportedSchemeIsRejected() {
        #expect(WebcalLinkConverter.convert("ftp://example.com/agenda.ics") == nil)
    }

    @Test func linkWithoutHostIsRejected() {
        #expect(WebcalLinkConverter.convert("https:///agenda.ics") == nil)
    }

    @Test func emptyInputDoesNothing() {
        #expect(WebcalLinkConverter.convert("") == nil)
    }

    @Test func whitespaceOnlyInputDoesNothing() {
        #expect(WebcalLinkConverter.convert("   ") == nil)
    }
}

import Testing
import Foundation
@testable import Bovexa

final class FakeSpeechRecognizing: SpeechRecognizing, @unchecked Sendable {
    var isLocaleSupported = true
    var authorizationGranted = true
    var startThrows = false
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    func requestAuthorization() async -> Bool { authorizationGranted }

    func startRecognition(onPartialTranscript: @escaping (String) -> Void, onError: @escaping (String) -> Void) throws {
        startCallCount += 1
        if startThrows { throw SpeechRecognitionEngineError.unavailable }
    }

    func stopRecognition() {
        stopCallCount += 1
    }
}

/// SpeechToTextService — valkuil J: permissie-weigering/onbeschikbaarheid geeft een
/// foutmelding of doet stil niets, nooit een crash. Geport uit useSpeechToText.ts.
@MainActor
struct SpeechToTextServiceTests {
    @Test func unavailableLocaleMeansAvailableIsFalseAndStartDoesNothing() async {
        let engine = FakeSpeechRecognizing()
        engine.isLocaleSupported = false
        let service = SpeechToTextService(engine: engine)
        #expect(service.available == false)

        await service.start()
        #expect(service.listening == false)
        #expect(engine.startCallCount == 0)
    }

    @Test func permissionDeniedSetsErrorWithoutCrashingAndStaysNotListening() async {
        let engine = FakeSpeechRecognizing()
        engine.authorizationGranted = false
        let service = SpeechToTextService(engine: engine)

        await service.start()
        #expect(service.listening == false)
        #expect(service.error == "Geef microfoon- en spraaktoegang in Instellingen om te dicteren.")
        #expect(engine.startCallCount == 0)
    }

    @Test func successfulStartSetsListeningTrue() async {
        let engine = FakeSpeechRecognizing()
        let service = SpeechToTextService(engine: engine)

        await service.start()
        #expect(service.listening == true)
        #expect(service.error == nil)
        #expect(engine.startCallCount == 1)
    }

    @Test func engineThrowOnStartSetsErrorAndDoesNotCrash() async {
        let engine = FakeSpeechRecognizing()
        engine.startThrows = true
        let service = SpeechToTextService(engine: engine)

        await service.start()
        #expect(service.listening == false)
        #expect(service.error == "Spraakherkenning kon niet starten.")
    }

    @Test func stopCallsEngineAndClearsListening() async {
        let engine = FakeSpeechRecognizing()
        let service = SpeechToTextService(engine: engine)
        await service.start()
        service.stop()
        #expect(service.listening == false)
        #expect(engine.stopCallCount == 1)
    }

    @Test func stopOnUnavailableServiceDoesNothing() {
        let engine = FakeSpeechRecognizing()
        engine.isLocaleSupported = false
        let service = SpeechToTextService(engine: engine)
        service.stop()
        #expect(engine.stopCallCount == 0)
    }

    @Test func resetClearsTranscript() async {
        let service = SpeechToTextService(engine: FakeSpeechRecognizing())
        service.reset()
        #expect(service.transcript.isEmpty)
    }

    @Test func toggleStartsWhenNotListeningAndStopsWhenListening() async {
        let engine = FakeSpeechRecognizing()
        let service = SpeechToTextService(engine: engine)

        await service.toggle()
        #expect(service.listening == true)

        await service.toggle()
        #expect(service.listening == false)
        #expect(engine.stopCallCount == 1)
    }
}

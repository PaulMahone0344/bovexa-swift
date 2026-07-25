import Foundation

/// Dicteren met live transcript — geport uit useSpeechToText.ts. Enige taak: mic aan/
/// uit + transcript; geen agenda-logica hier, de caller voedt het transcript in een
/// tekstveld. Permissie-weigering zet een foutmelding, nooit een crash (valkuil J).
@MainActor
final class SpeechToTextService: ObservableObject {
    @Published private(set) var listening = false
    @Published private(set) var transcript = ""
    @Published var error: String?

    let available: Bool
    private let engine: SpeechRecognizing

    init(engine: SpeechRecognizing = SFSpeechRecognitionEngine()) {
        self.engine = engine
        available = engine.isLocaleSupported
    }

    func start() async {
        guard available, !listening else { return }
        error = nil
        transcript = ""

        guard await engine.requestAuthorization() else {
            error = "Geef microfoon- en spraaktoegang in Instellingen om te dicteren."
            return
        }

        do {
            try engine.startRecognition(
                onPartialTranscript: { [weak self] text in
                    guard let self, !text.isEmpty else { return }
                    self.transcript = text
                },
                onError: { [weak self] message in
                    guard let self else { return }
                    self.error = message
                    self.listening = false
                }
            )
            listening = true
        } catch {
            self.error = "Spraakherkenning kon niet starten."
            listening = false
        }
    }

    func stop() {
        guard available else { return }
        engine.stopRecognition()
        listening = false
    }

    func toggle() async {
        if listening {
            stop()
        } else {
            await start()
        }
    }

    func reset() {
        transcript = ""
    }
}

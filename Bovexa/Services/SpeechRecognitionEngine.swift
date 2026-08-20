import AVFoundation
import Foundation
import Speech

/// Abstractie over SFSpeechRecognizer/AVAudioEngine — testbaar zonder echte
/// microfoon-/spraakpermissies.
protocol SpeechRecognizing: AnyObject {
    var isLocaleSupported: Bool { get }
    func requestAuthorization() async -> Bool
    func startRecognition(onPartialTranscript: @escaping (String) -> Void, onError: @escaping (String) -> Void) throws
    func stopRecognition()
}

enum SpeechRecognitionEngineError: Error {
    case unavailable
}

/// Dicteren met live transcript, Nederlands, on-device waar mogelijk (valkuil J).
/// Geport uit useSpeechToText.ts (ExpoSpeechRecognitionModule → hier SFSpeechRecognizer).
final class SFSpeechRecognitionEngine: SpeechRecognizing {
    private static let localeIdentifier = "nl-NL"

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: SFSpeechRecognitionEngine.localeIdentifier))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    var isLocaleSupported: Bool {
        recognizer?.isAvailable ?? false
    }

    func requestAuthorization() async -> Bool {
        let speechGranted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechGranted else { return false }
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecognition(onPartialTranscript: @escaping (String) -> Void, onError: @escaping (String) -> Void) throws {
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechRecognitionEngineError.unavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        self.request = request

        // ZEKERHEID LAAG (M11 plak 3i) — alleen op een echt toestel te zien.
        // Zonder een expliciete categorie draait de sessie op de standaard
        // (soloAmbient) en kan het inputformaat 0 kanalen hebben; installTap gooit
        // dan een NSException of start() faalt. Apple's SpokenWord-voorbeeld zet
        // dit altijd vóór de tap.
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                onPartialTranscript(result.bestTranscription.formattedString)
            }
            guard error != nil else { return }
            // Een geannuleerde SFSpeechRecognitionTask roept deze handler aan mét
            // een fout ("Recognition request was canceled"). Die kwam als
            // "Spraak"-alert met Engelse systeemtekst op het scherm na élke stop.
            // `task` is in teardown al op nil gezet, dus dat is het signaal dat wij
            // zelf gestopt zijn.
            guard self?.task != nil else { return }
            onError(error?.localizedDescription ?? "Spraakherkenning mislukt.")
            self?.teardown()
        }
    }

    func stopRecognition() {
        teardown()
    }

    private func teardown() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        // Eerst nil, dán cancel: de handler hierboven gebruikt `task == nil` om te
        // zien dat het stoppen van ons kwam en niet van de herkenner.
        let running = task
        task = nil
        running?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

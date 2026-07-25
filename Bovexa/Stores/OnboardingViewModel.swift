import Foundation

/// Keuzestap direct na registratie (valkuil A): bedrijf starten, code invoeren
/// (voorgevuld bij een uitnodiging, valkuil B) of overslaan. Hergebruikt
/// `CompanyRepository` — dezelfde aanroepen als de Bedrijf-tab in m5, geen tweede.
@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Mode: Equatable {
        case choice, name, code
    }

    @Published private(set) var mode: Mode = .choice
    @Published var companyName = ""
    @Published var joinCode = ""
    @Published private(set) var busy = false
    @Published var errorMessage: String?

    private let repository: CompanyRepository

    init(repository: CompanyRepository = CompanyRepository()) {
        self.repository = repository
    }

    func openMode(_ newMode: Mode) {
        errorMessage = nil
        mode = newMode
    }

    /// Valkuil B: een code uit een uitnodigingslink staat al klaar in
    /// `JoinCoordinator.pendingCode` — die neemt de code-stap meteen over.
    func applyPrefilledCode(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        joinCode = trimmed
        mode = .code
    }

    @discardableResult
    func startCompany(token: String) async -> Bool {
        let trimmed = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            errorMessage = "Vul een bedrijfsnaam in (min. 2 tekens)."
            return false
        }
        errorMessage = nil
        busy = true
        defer { busy = false }
        do {
            _ = try await repository.createCompany(name: trimmed, token: token)
            return true
        } catch {
            errorMessage = (error as? CompanyError)?.message ?? "Bedrijf aanmaken mislukt."
            return false
        }
    }

    @discardableResult
    func joinCompanyAction(token: String) async -> Bool {
        let trimmed = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Vul een bedrijfscode in."
            return false
        }
        errorMessage = nil
        busy = true
        defer { busy = false }
        do {
            _ = try await repository.joinCompany(code: trimmed, token: token)
            return true
        } catch {
            errorMessage = (error as? CompanyError)?.message ?? "Toetreden mislukt."
            return false
        }
    }
}

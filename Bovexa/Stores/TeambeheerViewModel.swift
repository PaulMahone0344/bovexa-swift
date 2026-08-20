import Foundation

/// Viewmodel voor het teambeheer-scherm: uitnodigen (code/deel/mail), logo en
/// bedrijfsprofiel. Alleen bereikbaar voor admins (BedrijfView verbergt de ingang —
/// valkuil D); deze viewmodel doet zijn eigen listMembers-call, los van de Bedrijf-tab.
@MainActor
final class TeambeheerViewModel: ObservableObject {
    @Published private(set) var loading = true
    @Published private(set) var loadError = false
    @Published private(set) var org: CompanyOrgProfile?
    @Published private(set) var seatsMax = 0
    @Published private(set) var joinCode = ""
    @Published private(set) var activeMemberCount = 0

    @Published private(set) var rotating = false
    @Published var copied = false
    @Published private(set) var logoBusy = false
    @Published var inviteEmail = ""
    @Published private(set) var inviteSending = false
    @Published var inviteSentMessage: String?
    @Published var errorMessage: String?

    @Published var address = ""
    @Published var phone = ""
    @Published var email = ""
    @Published var timezone = "Europe/Amsterdam"
    @Published private(set) var defaultDurationMin = 30
    @Published var openingHours = OpeningHours()
    @Published private(set) var savingProfile = false

    /// Standaardduur-ondergrens — zelfde grens als de server ("Standaardduur moet
    /// minstens 5 minuten zijn").
    private static let minDurationMin = 5
    private static let durationStepMin = 15

    private let repository: CompanyRepository

    init(repository: CompanyRepository = CompanyRepository()) {
        self.repository = repository
    }

    var full: Bool { seatsMax > 0 && activeMemberCount >= seatsMax }
    /// Moment van de laatste geslaagde profielopslag; de view toont daar kort
    /// "Opgeslagen" op (4d).
    @Published private(set) var profileSavedAt: Date?

    func load(token: String) async {
        loading = true
        loadError = false
        do {
            let response = try await repository.listMembers(token: token)
            org = response.org
            seatsMax = response.seatsMax
            joinCode = response.joinCode
            activeMemberCount = response.items.filter { $0.status == "active" }.count
            applyProfileFields(from: response.org)
        } catch {
            org = nil
            loadError = true
        }
        loading = false
    }

    private func applyProfileFields(from org: CompanyOrgProfile?) {
        address = org?.address ?? ""
        phone = org?.phone ?? ""
        email = org?.email ?? ""
        let orgTimezone = org?.timezone ?? ""
        timezone = orgTimezone.isEmpty ? "Europe/Amsterdam" : orgTimezone
        let orgDuration = org?.defaultDurationMin ?? 0
        defaultDurationMin = orgDuration > 0 ? orgDuration : 30
        openingHours = org?.openingHours ?? .empty
    }

    func decrementDuration() {
        defaultDurationMin = max(Self.minDurationMin, defaultDurationMin - Self.durationStepMin)
    }

    func incrementDuration() {
        defaultDurationMin += Self.durationStepMin
    }

    /// Leeg = gesloten: alleen wanneer zowel open als close leeg zijn, wist het de dag.
    func setDayHours(_ keyPath: WritableKeyPath<OpeningHours, DayHours?>, open: String, close: String) {
        openingHours[keyPath: keyPath] = (open.isEmpty && close.isEmpty) ? nil : DayHours(open: open, close: close)
    }

    /// Alleen dagen waar zowel open als close zijn ingevuld gaan mee — een halfvol
    /// veld telt bij het opslaan als gesloten (zelfde regel als de RN-form).
    private func cleanedHours() -> OpeningHours {
        var result = OpeningHours.empty
        for (keyPath, _) in OpeningHours.dayOrder {
            if let day = openingHours[keyPath: keyPath], !day.open.isEmpty, !day.close.isEmpty {
                result[keyPath: keyPath] = day
            }
        }
        return result
    }

    func saveProfile(token: String) async {
        savingProfile = true
        defer { savingProfile = false }
        var update = CompanyProfileUpdate()
        update.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        update.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        update.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        update.timezone = timezone.trimmingCharacters(in: .whitespacesAndNewlines)
        update.defaultDurationMin = defaultDurationMin
        update.openingHours = cleanedHours()
        do {
            let response = try await repository.updateProfile(update, token: token)
            address = response.address
            phone = response.phone
            email = response.email
            timezone = response.timezone.isEmpty ? "Europe/Amsterdam" : response.timezone
            defaultDurationMin = response.defaultDurationMin > 0 ? response.defaultDurationMin : defaultDurationMin
            openingHours = response.openingHours ?? .empty
            // Na succes gebeurde er zichtbaar niets: geen haptic, geen tekst (4d).
            Haptics.success()
            profileSavedAt = Date()
        } catch {
            errorMessage = (error as? CompanyError)?.message ?? "Bedrijfsprofiel opslaan mislukt."
        }
    }

    func rotateCode(token: String) async {
        rotating = true
        defer { rotating = false }
        do {
            let result = try await repository.rotateCode(token: token)
            joinCode = result.joinCode
        } catch {
            errorMessage = (error as? CompanyError)?.message ?? "Code roteren mislukt."
        }
    }

    func sendInvite(token: String) async {
        let trimmed = inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !inviteSending else { return }
        inviteSending = true
        defer { inviteSending = false }
        do {
            let result = try await repository.sendInvite(email: trimmed, token: token)
            inviteEmail = ""
            inviteSentMessage = "Uitnodiging gestuurd naar \(result.email)."
        } catch {
            errorMessage = (error as? CompanyError)?.message ?? "Uitnodiging versturen mislukt."
        }
    }

    func uploadLogo(fileName: String, mimeType: String, fileData: Data, token: String) async {
        guard !logoBusy else { return }
        logoBusy = true
        defer { logoBusy = false }
        do {
            let result = try await repository.uploadLogo(fileName: fileName, mimeType: mimeType, fileData: fileData, token: token)
            applyLogo(result.logo)
        } catch {
            errorMessage = (error as? CompanyError)?.message ?? "Logo uploaden mislukt."
        }
    }

    func removeLogo(token: String) async {
        guard !logoBusy else { return }
        logoBusy = true
        defer { logoBusy = false }
        do {
            let result = try await repository.removeLogo(token: token)
            applyLogo(result.logo)
        } catch {
            errorMessage = (error as? CompanyError)?.message ?? "Logo verwijderen mislukt."
        }
    }

    private func applyLogo(_ logo: String) {
        guard let current = org else { return }
        org = CompanyOrgProfile(
            id: current.id, name: current.name, logo: logo, icsToken: current.icsToken,
            address: current.address, phone: current.phone, email: current.email,
            openingHours: current.openingHours, timezone: current.timezone, defaultDurationMin: current.defaultDurationMin
        )
    }
}

import Foundation

/// UI-staat voor Profiel bewerken (plak 3): naam, gekozen/verwijderde foto.
/// Puur lokale staat — de daadwerkelijke opslag gebeurt via
/// `AuthStore.updateProfile`, die de payload-vorm hieronder (`avatarUpdate`)
/// gebruikt (valkuil J, zelfde multipart-patroon als het bedrijfslogo).
@MainActor
final class ProfielBewerkenViewModel: ObservableObject {
    struct PickedImage: Equatable {
        let fileName: String
        let mimeType: String
        let data: Data
    }

    @Published var naam: String
    @Published private(set) var pickedImage: PickedImage?
    @Published private(set) var removePhoto = false
    @Published private(set) var busy = false
    @Published var errorMessage: String?

    private let hadExistingAvatar: Bool

    init(naam: String, existingAvatar: String?) {
        self.naam = naam
        self.hadExistingAvatar = !(existingAvatar ?? "").isEmpty
    }

    /// "Foto verwijderen" mag alleen verschijnen als er iets te verwijderen is —
    /// een nieuw gekozen foto, of een al bestaande.
    var hasPhoto: Bool {
        if pickedImage != nil { return true }
        if removePhoto { return false }
        return hadExistingAvatar
    }

    var trimmedNaam: String { naam.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canSave: Bool { !trimmedNaam.isEmpty && !busy }

    func selectPhoto(_ image: PickedImage) {
        pickedImage = image
        removePhoto = false
    }

    func markRemovePhoto() {
        pickedImage = nil
        removePhoto = true
    }

    func setBusy(_ value: Bool) {
        busy = value
    }

    /// Payload-vorm: nil = geen wijziging aan de avatar, .file = nieuwe foto
    /// uploaden, .remove = bestaande foto wissen.
    var avatarUpdate: PBClient.AvatarUpdate? {
        if let pickedImage {
            return .file(fileName: pickedImage.fileName, mimeType: pickedImage.mimeType, fileData: pickedImage.data)
        }
        if removePhoto {
            return .remove
        }
        return nil
    }
}

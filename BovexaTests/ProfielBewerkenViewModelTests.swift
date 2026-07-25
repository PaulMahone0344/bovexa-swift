import Testing
import Foundation
@testable import Bovexa

@MainActor
struct ProfielBewerkenViewModelTests {
    private func image(_ name: String = "avatar.jpg") -> ProfielBewerkenViewModel.PickedImage {
        .init(fileName: name, mimeType: "image/jpeg", data: Data([0x01, 0x02]))
    }

    // MARK: - Payload-vorm (valkuil J)

    @Test func noChangeYieldsNilAvatarUpdate() {
        let vm = ProfielBewerkenViewModel(naam: "Ibrahim", existingAvatar: "foto.jpg")
        #expect(vm.avatarUpdate == nil)
    }

    @Test func selectingPhotoYieldsFileAvatarUpdate() {
        let vm = ProfielBewerkenViewModel(naam: "Ibrahim", existingAvatar: nil)
        vm.selectPhoto(image())
        guard case .file(let fileName, let mimeType, let data) = vm.avatarUpdate else {
            Issue.record("verwachtte .file")
            return
        }
        #expect(fileName == "avatar.jpg")
        #expect(mimeType == "image/jpeg")
        #expect(data == Data([0x01, 0x02]))
    }

    @Test func removingPhotoYieldsRemoveAvatarUpdate() {
        let vm = ProfielBewerkenViewModel(naam: "Ibrahim", existingAvatar: "foto.jpg")
        vm.markRemovePhoto()
        guard case .remove = vm.avatarUpdate else {
            Issue.record("verwachtte .remove")
            return
        }
    }

    @Test func selectingPhotoAfterRemoveOverridesRemove() {
        let vm = ProfielBewerkenViewModel(naam: "Ibrahim", existingAvatar: "foto.jpg")
        vm.markRemovePhoto()
        vm.selectPhoto(image())
        guard case .file = vm.avatarUpdate else {
            Issue.record("verwachtte .file")
            return
        }
    }

    // MARK: - "Verwijderen" alleen bij een foto

    @Test func noPhotoMeansRemoveButtonHidden() {
        let vm = ProfielBewerkenViewModel(naam: "Ibrahim", existingAvatar: nil)
        #expect(!vm.hasPhoto)
    }

    @Test func existingAvatarShowsRemoveButton() {
        let vm = ProfielBewerkenViewModel(naam: "Ibrahim", existingAvatar: "foto.jpg")
        #expect(vm.hasPhoto)
    }

    @Test func emptyStringAvatarDoesNotShowRemoveButton() {
        let vm = ProfielBewerkenViewModel(naam: "Ibrahim", existingAvatar: "")
        #expect(!vm.hasPhoto)
    }

    @Test func pickingNewPhotoShowsRemoveButton() {
        let vm = ProfielBewerkenViewModel(naam: "Ibrahim", existingAvatar: nil)
        vm.selectPhoto(image())
        #expect(vm.hasPhoto)
    }

    @Test func removingThenPhotoGoneHidesRemoveButton() {
        let vm = ProfielBewerkenViewModel(naam: "Ibrahim", existingAvatar: "foto.jpg")
        vm.markRemovePhoto()
        #expect(!vm.hasPhoto)
    }

    // MARK: - Opslaan

    @Test func blankNameBlocksSave() {
        let vm = ProfielBewerkenViewModel(naam: "  ", existingAvatar: nil)
        #expect(!vm.canSave)
    }

    @Test func busyBlocksSave() {
        let vm = ProfielBewerkenViewModel(naam: "Ibrahim", existingAvatar: nil)
        vm.setBusy(true)
        #expect(!vm.canSave)
    }
}

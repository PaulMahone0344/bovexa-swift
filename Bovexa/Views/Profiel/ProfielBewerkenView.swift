import SwiftUI
import PhotosUI
import UIKit

/// Profiel bewerken (plak 3): avatar kiezen/verwijderen + naam. Geen native
/// bijsnijd-stap zoals de RN-app (expo-image-picker's vierkante crop) — PhotosUI
/// heeft dat niet ingebouwd; de preview toont de foto wel al rond/vierkant
/// bijgesneden via `.scaledToFill()` + `clipShape`. Zie eindrapport.
struct ProfielBewerkenView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ProfielBewerkenViewModel
    @State private var selection: PhotosPickerItem?
    @State private var previewImage: Image?

    private let existingAvatarURL: URL?

    init(user: AgendaUser) {
        self.existingAvatarURL = AvatarURLBuilder.url(userId: user.id, avatar: user.avatar)
        _viewModel = StateObject(wrappedValue: ProfielBewerkenViewModel(naam: user.naam ?? "", existingAvatar: user.avatar))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: BovexaTheme.Space.xl) {
                        VStack(spacing: BovexaTheme.Space.sm) {
                            avatarPreview

                            HStack(spacing: BovexaTheme.Space.lg) {
                                PhotosPicker(selection: $selection, matching: .images) {
                                    Text(viewModel.hasPhoto ? "Foto wijzigen" : "Foto kiezen")
                                }
                                .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                                .foregroundStyle(BovexaTheme.Colors.accent)

                                if viewModel.hasPhoto {
                                    Button("Foto verwijderen") {
                                        Haptics.selection()
                                        viewModel.markRemovePhoto()
                                        previewImage = nil
                                    }
                                    .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                                    .foregroundStyle(BovexaTheme.Colors.muted)
                                }
                            }
                        }
                        .padding(.top, BovexaTheme.Space.lg)

                        GlassCard {
                            VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
                                Text("NAAM")
                                    .font(BovexaTheme.TypeStyle.footnote.weight(.medium))
                                    .foregroundStyle(BovexaTheme.Colors.muted)
                                TextField("Voor- en achternaam", text: $viewModel.naam)
                                    .textInputAutocapitalization(.words)
                                    .font(BovexaTheme.TypeStyle.body)
                                    .foregroundStyle(BovexaTheme.Colors.ink)
                            }
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(BovexaTheme.TypeStyle.footnote)
                                .foregroundStyle(BovexaTheme.Colors.danger)
                        }

                        Button {
                            Task { await save() }
                        } label: {
                            HStack {
                                Spacer()
                                if viewModel.busy {
                                    ProgressView().tint(BovexaTheme.Colors.white)
                                } else {
                                    Text("Opslaan").font(BovexaTheme.TypeStyle.headline)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.glassProminentBrand)
                        .disabled(!viewModel.canSave)
                    }
                    .padding(BovexaTheme.Space.xl)
                }
            }
            .navigationTitle("Profiel bewerken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
            }
        }
        .onChange(of: selection) { _, newItem in
            Task { await loadPicked(newItem) }
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let previewImage {
            previewImage
                .resizable()
                .scaledToFill()
                .frame(width: 92, height: 92)
                .clipShape(Circle())
                .overlay(Circle().stroke(BovexaTheme.Colors.edge, lineWidth: 1))
        } else {
            AvatarView(initial: initial, url: viewModel.hasPhoto ? existingAvatarURL : nil, size: 92)
        }
    }

    private var initial: String {
        let trimmed = viewModel.naam.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0).uppercased() } ?? "?"
    }

    private func loadPicked(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        viewModel.selectPhoto(.init(fileName: "avatar.jpg", mimeType: "image/jpeg", data: data))
        if let uiImage = UIImage(data: data) {
            previewImage = Image(uiImage: uiImage)
        }
    }

    private func save() async {
        viewModel.setBusy(true)
        defer { viewModel.setBusy(false) }
        do {
            try await authStore.updateProfile(naam: viewModel.trimmedNaam, avatar: viewModel.avatarUpdate)
            dismiss()
        } catch {
            viewModel.errorMessage = "Kon je profiel niet opslaan. Probeer het nog een keer."
        }
    }
}

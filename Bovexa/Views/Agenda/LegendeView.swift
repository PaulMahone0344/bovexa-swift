import SwiftUI

/// Legenda als eigen sheet, op de plek waar de iOS Agenda zijn agendalijst heeft:
/// achter een knop in de chrome, niet inline boven de kalender. Als kaart in de
/// maandweergave nam hij vaste hoogte weg en dwong hij een inklap-mechaniek dat de
/// lijst half verstopte; in een sheet is er ruimte en staat de lijst altijd open.
/// Kleur wijzigen werkt overal meteen door (LabelStore is de gedeelde bron voor
/// EventHelpers.eventColor). Verwijderen alleen zichtbaar voor admins (valkuil G);
/// verwijderde labels laten afspraken netjes terugvallen (valkuil H, in LabelStore).
struct LegendeView: View {
    @StateObject private var viewModel: LegendeViewModel
    @Environment(\.dismiss) private var dismiss
    /// Rechtstreeks observeren, net als elke andere view die labels tekent. Via
    /// `viewModel.labelStore` lezen werkt niet: een geneste ObservableObject laat
    /// de buitenste niet publiceren, dus de legenda hertekende nooit als de labels
    /// binnenkwamen en bleef "Nog geen labels" tonen tot de view opnieuw werd
    /// opgebouwd.
    @ObservedObject private var labelStore: LabelStore

    @State private var renamingLabel: AgendaLabel?
    @State private var renameText = ""
    @State private var colorPickingLabelId: String?
    @State private var pendingDelete: AgendaLabel?
    @State private var showNewLabelForm = false
    @State private var newLabelName = ""
    @State private var newLabelColor = BovexaTheme.LabelPalette.options[0].hex

    /// Vrije kleur (ColorPicker) voor een bestaand label. De picker vuurt bij
    /// elke sleep in het spectrum; de commit-taak debounced zodat niet elke
    /// tussenkleur een API-call wordt.
    @State private var customColor: Color = .white
    @State private var customCommitTask: Task<Void, Never>?
    /// Vrije kleur voor het nieuw-label-formulier — commit gebeurt daar pas bij
    /// "Toevoegen", dus geen debounce nodig.
    @State private var newCustomColor = Color(hex: BovexaTheme.LabelPalette.options[0].hex)

    init(userId: String, org: String, token: String, labelStore: LabelStore) {
        _viewModel = StateObject(wrappedValue: LegendeViewModel(userId: userId, org: org, token: token, labelStore: labelStore))
        _labelStore = ObservedObject(wrappedValue: labelStore)
    }

    /// Vaste regel "Externe agenda" onderaan (m9 plak 4, valkuil D) — niet aan te
    /// tikken, niet te hernoemen, alleen zichtbaar als er ook echt een agenda
    /// gekozen is op Profiel.
    private var showsExternalCalendarRow: Bool {
        !ExternalCalendarSelectionPreference.selectedIds().isEmpty
    }

    private var externalCalendarRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(BovexaTheme.Colors.muted)
                .frame(width: 10, height: 10)
            Text("Externe agenda")
                .font(BovexaTheme.TypeStyle.footnote)
                .foregroundStyle(BovexaTheme.Colors.inkSoft)
                .lineLimit(1)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                        if labelStore.orderedLabels.isEmpty {
                            EmptyStateView(
                                systemImage: "tag",
                                text: "Nog geen labels. Voeg er één toe om afspraken makkelijker terug te zien.",
                                surface: .background
                            )
                        } else {
                            // Beide acties zijn onzichtbaar zonder deze regel: de
                            // naam en de stip zijn knoppen, maar zien er niet als
                            // knop uit. Apple zet daar een (i) naast; één regel
                            // uitleg is lichter en zegt hetzelfde.
                            Text("Tik een naam om te hernoemen, of de stip voor een andere kleur.")
                                .font(BovexaTheme.TypeStyle.footnote)
                                .foregroundStyle(BovexaTheme.Colors.inkSoft)

                            GlassCard(padding: BovexaTheme.Space.md) {
                                VStack(spacing: 0) {
                                    ForEach(labelStore.orderedLabels) { label in
                                        labelRow(label)
                                        if label.id != labelStore.orderedLabels.last?.id || showsExternalCalendarRow {
                                            Divider().overlay(BovexaTheme.Colors.edgeSoft)
                                        }
                                    }
                                    if showsExternalCalendarRow {
                                        externalCalendarRow.padding(.vertical, BovexaTheme.Space.sm)
                                    }
                                }
                            }
                        }

                        if showNewLabelForm {
                            newLabelForm
                        } else {
                            newLabelButton
                        }
                    }
                    .padding(BovexaTheme.Space.xl)
                }
            }
            .navigationTitle("Legenda")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Sluiten")
                }
            }
        }
        .task { await viewModel.loadRole() }
        .alert("Label hernoemen", isPresented: Binding(get: { renamingLabel != nil }, set: { if !$0 { renamingLabel = nil } })) {
            TextField("Naam", text: $renameText)
            Button("Opslaan") {
                if let label = renamingLabel {
                    Task { await viewModel.rename(label, to: renameText) }
                }
            }
            Button("Annuleren", role: .cancel) {}
        }
        .alert("Label verwijderen?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Verwijderen", role: .destructive) {
                if let label = pendingDelete {
                    Task { await viewModel.delete(label) }
                }
            }
            Button("Annuleren", role: .cancel) {}
        } message: {
            Text("Afspraken met dit label houden hun categoriekleur.")
        }
        .alert("Mislukt", isPresented: $viewModel.actionFailedAlert) {
            Button("Oké", role: .cancel) {}
        } message: {
            Text("Kon dit niet opslaan. Probeer het nog een keer.")
        }
    }

    private func labelRow(_ label: AgendaLabel) -> some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
            HStack(spacing: BovexaTheme.Space.sm) {
                Button {
                    Haptics.selection()
                    // Seeden vóór openen: zo toont de vrije-kleur-well de huidige
                    // labelkleur en vuurt onChange niet meteen een commit af.
                    customColor = Color(hex: label.kleur)
                    withAnimation(.snappy) { colorPickingLabelId = colorPickingLabelId == label.id ? nil : label.id }
                } label: {
                    // Bolletje blijft 18pt, raakvlak 44 (M11 patroon B).
                    Circle()
                        .fill(Color(hex: label.kleur))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1))
                        .minTapTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Kleur van \(label.naam) wijzigen")

                Button {
                    Haptics.selection()
                    renameText = label.naam
                    renamingLabel = label
                } label: {
                    // Hele rij tot aan de prullenbak hernoemt; alles rechts van de
                    // naam was dood.
                    Text(label.naam)
                        .font(BovexaTheme.TypeStyle.body.weight(.medium))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                        .lineLimit(1)
                        .rowTapTarget()
                }
                .buttonStyle(.plain)

                if viewModel.isAdmin {
                    Button {
                        Haptics.selection()
                        pendingDelete = label
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(BovexaTheme.Colors.danger)
                            .minTapTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Label \(label.naam) verwijderen")
                }
            }

            if colorPickingLabelId == label.id {
                colorSwatchRow(for: label)
            }
        }
    }

    private func colorSwatchRow(for label: AgendaLabel) -> some View {
        // Spacing van xs (6) naar 0: de swatches zijn nu 44pt raakvlak in plaats
        // van 24pt, dus zonder die verlaging rekt de rij hart-op-hart op.
        FlowLayout(spacing: 0) {
            ForEach(BovexaTheme.LabelPalette.options) { option in
                let isCurrent = option.hex.caseInsensitiveCompare(label.kleur) == .orderedSame
                // Button in plaats van Circle().onTapGesture: een Shape heeft geen
                // knop-rol, dus met VoiceOver was hier geen kleur te kiezen, en er
                // was geen ingedrukt-feedback.
                Button {
                    Haptics.selection()
                    customCommitTask?.cancel()
                    Task { await viewModel.updateColor(label, to: option.hex) }
                    withAnimation(.snappy) { colorPickingLabelId = nil }
                } label: {
                    Circle()
                        .fill(Color(hex: option.hex))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().strokeBorder(BovexaTheme.Colors.white, lineWidth: isCurrent ? 2.5 : 0))
                        .overlay(Circle().strokeBorder(BovexaTheme.Colors.edge, lineWidth: isCurrent ? 0 : 1))
                        .minTapTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.name)
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
            }

            // Vrije kleur via de systeem-picker (raster/spectrum/sliders). Sluit
            // de rij hier bewust niet: de picker-sheet leeft in deze view, en
            // tijdens slepen komen er continu tussenkleuren binnen — vandaar
            // debounce in plaats van commit-per-wijziging.
            ColorPicker("Vrije kleur", selection: $customColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: customColor) { _, newValue in
                    let hex = newValue.hexString
                    guard hex.caseInsensitiveCompare(label.kleur) != .orderedSame else { return }
                    customCommitTask?.cancel()
                    customCommitTask = Task {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        guard !Task.isCancelled else { return }
                        await viewModel.updateColor(label, to: hex)
                    }
                }
        }
        .padding(.bottom, BovexaTheme.Space.xs)
    }

    private var newLabelButton: some View {
        Button {
            Haptics.selection()
            withAnimation(.snappy) { showNewLabelForm.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("Nieuw label")
                    .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
            }
            .foregroundStyle(BovexaTheme.Colors.accent)
            // `.padding(.top)` stond op de Button en telde dus niet mee voor het
            // raakvlak; nu een echte 44pt hoogte in het label.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var newLabelForm: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            TextField("Naam", text: $newLabelName)
                .padding(.horizontal, BovexaTheme.Space.md)
                .frame(minHeight: 44)
                .background(BovexaTheme.Colors.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                        .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))

            // Spacing 0: de swatches zijn nu 44pt raakvlak in plaats van 24pt.
            FlowLayout(spacing: 0) {
                ForEach(BovexaTheme.LabelPalette.options) { option in
                    let isCurrent = newLabelColor == option.hex
                    Button {
                        Haptics.selection()
                        newLabelColor = option.hex
                    } label: {
                        Circle()
                            .fill(Color(hex: option.hex))
                            .frame(width: 24, height: 24)
                            .overlay(Circle().strokeBorder(BovexaTheme.Colors.white, lineWidth: isCurrent ? 2.5 : 0))
                            .overlay(Circle().strokeBorder(BovexaTheme.Colors.edge, lineWidth: isCurrent ? 0 : 1))
                            .minTapTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.name)
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                }

                ColorPicker("Vrije kleur", selection: $newCustomColor, supportsOpacity: false)
                    .labelsHidden()
                    .onChange(of: newCustomColor) { _, newValue in
                        newLabelColor = newValue.hexString
                    }
            }

            Button("Toevoegen") {
                Task {
                    await viewModel.create(naam: newLabelName, kleur: newLabelColor)
                    newLabelName = ""
                    withAnimation(.snappy) { showNewLabelForm = false }
                }
            }
            .buttonStyle(.glassProminentBrand)
            .frame(maxWidth: .infinity, minHeight: 42)
            .disabled(newLabelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(BovexaTheme.Space.md)
        .background(BovexaTheme.Colors.glassSoft)
        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
    }
}

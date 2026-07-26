import SwiftUI

/// Zichtbare legenda in de Agenda (m7 plak 6) — niet weggestopt in het lagen-menu.
/// Kleur wijzigen werkt overal meteen door (LabelStore is de gedeelde bron voor
/// EventHelpers.eventColor). Verwijderen alleen zichtbaar voor admins (valkuil G);
/// verwijderde labels laten afspraken netjes terugvallen (valkuil H, in LabelStore).
struct LegendeView: View {
    @StateObject private var viewModel: LegendeViewModel

    @State private var renamingLabel: AgendaLabel?
    @State private var renameText = ""
    @State private var colorPickingLabelId: String?
    @State private var pendingDelete: AgendaLabel?
    @State private var isExpanded = false
    @State private var showNewLabelForm = false
    @State private var newLabelName = ""
    @State private var newLabelColor = BovexaTheme.LabelPalette.options[0].hex

    init(userId: String, org: String, token: String, labelStore: LabelStore) {
        _viewModel = StateObject(wrappedValue: LegendeViewModel(userId: userId, org: org, token: token, labelStore: labelStore))
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                header

                if viewModel.labelStore.orderedLabels.isEmpty {
                    Text("Nog geen labels. Voeg er één toe om afspraken makkelijker terug te zien.")
                        .font(BovexaTheme.TypeStyle.footnote)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                    newLabelButton
                } else if isExpanded {
                    VStack(spacing: 0) {
                        ForEach(viewModel.labelStore.orderedLabels) { label in
                            labelRow(label)
                            if label.id != viewModel.labelStore.orderedLabels.last?.id {
                                Divider().overlay(BovexaTheme.Colors.edgeSoft)
                            }
                        }
                    }
                    newLabelButton
                } else {
                    collapsedStrip
                }

                if showNewLabelForm { newLabelForm }
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

    /// Kop is de schakelaar. Ingeklapt blijft de legenda zichtbaar als strip, want
    /// de opdrachtgever vroeg om "niet weggestopt"; uitgeklapt vulde hij bij veel
    /// labels het halve scherm en duwde hij de maandkalender weg — de kaart staat
    /// buiten de ScrollView, dus daar viel niet langs te scrollen.
    private var header: some View {
        Button {
            Haptics.selection()
            withAnimation(.snappy) { isExpanded.toggle() }
        } label: {
            HStack(spacing: BovexaTheme.Space.xs) {
                Text("LEGENDA")
                    .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                    .foregroundStyle(BovexaTheme.Colors.accent)
                    .tracking(0.3)
                Spacer()
                if !viewModel.labelStore.orderedLabels.isEmpty {
                    Text(isExpanded ? "Klaar" : "Wijzigen")
                        .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                        .foregroundStyle(BovexaTheme.Colors.accent)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(BovexaTheme.Colors.accent)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.labelStore.orderedLabels.isEmpty)
    }

    /// Ingeklapte weergave: stip plus naam per label, horizontaal scrollend zodat
    /// tien labels de kaart niet laten groeien.
    private var collapsedStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BovexaTheme.Space.sm) {
                ForEach(viewModel.labelStore.orderedLabels) { label in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: label.kleur))
                            .frame(width: 10, height: 10)
                        Text(label.naam)
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.ink)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    private func labelRow(_ label: AgendaLabel) -> some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
            HStack(spacing: BovexaTheme.Space.sm) {
                Button {
                    Haptics.selection()
                    withAnimation(.snappy) { colorPickingLabelId = colorPickingLabelId == label.id ? nil : label.id }
                } label: {
                    Circle()
                        .fill(Color(hex: label.kleur))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1))
                }

                Button {
                    renameText = label.naam
                    renamingLabel = label
                } label: {
                    Text(label.naam)
                        .font(BovexaTheme.TypeStyle.body.weight(.medium))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                Spacer()

                if viewModel.isAdmin {
                    Button {
                        pendingDelete = label
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(BovexaTheme.Colors.danger)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, BovexaTheme.Space.xs)

            if colorPickingLabelId == label.id {
                colorSwatchRow { hex in
                    Task { await viewModel.updateColor(label, to: hex) }
                    withAnimation(.snappy) { colorPickingLabelId = nil }
                }
            }
        }
    }

    private func colorSwatchRow(onPick: @escaping (String) -> Void) -> some View {
        HStack(spacing: BovexaTheme.Space.xs) {
            ForEach(BovexaTheme.LabelPalette.options) { option in
                Circle()
                    .fill(Color(hex: option.hex))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1))
                    .onTapGesture {
                        Haptics.selection()
                        onPick(option.hex)
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
        }
        .padding(.top, BovexaTheme.Space.xs)
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

            HStack(spacing: BovexaTheme.Space.xs) {
                ForEach(BovexaTheme.LabelPalette.options) { option in
                    Circle()
                        .fill(Color(hex: option.hex))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().strokeBorder(BovexaTheme.Colors.white, lineWidth: newLabelColor == option.hex ? 2.5 : 0))
                        .overlay(Circle().strokeBorder(BovexaTheme.Colors.edge, lineWidth: newLabelColor == option.hex ? 0 : 1))
                        .onTapGesture {
                            Haptics.selection()
                            newLabelColor = option.hex
                        }
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

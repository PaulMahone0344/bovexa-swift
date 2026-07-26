import SwiftUI

/// Labelkiezer (m7): gekleurde stippen met naam, vinkje bij de gekozen — opbouw
/// zoals de agenda-kiezer in de iOS Agenda (schermafbeelding van de opdrachtgever).
/// "Nieuw label" is meteen bruikbaar: aanmaken selecteert het label direct, zonder
/// scherm-refresh (LabelStore.add). Labels zijn van het bedrijf, niet van de
/// gebruiker (valkuil G) — iedereen mag hier toevoegen.
struct LabelPickerView: View {
    @ObservedObject var labelStore: LabelStore
    @Binding var selectedLabelId: String?
    let org: String
    let token: String
    var labelRepository: LabelRepository = LabelRepository()
    var disabled: Bool = false

    @State private var showNewLabelForm = false
    @State private var newLabelName = ""
    @State private var newLabelColor = BovexaTheme.LabelPalette.options[0].hex
    @State private var isCreating = false

    var body: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            FlowLayout(spacing: BovexaTheme.Space.xs) {
                noneChip
                ForEach(labelStore.orderedLabels) { label in
                    labelChip(label)
                }
                newLabelChip
            }
            if showNewLabelForm {
                newLabelForm
            }
        }
    }

    private var noneChip: some View {
        chip(title: "Geen label", color: nil, active: selectedLabelId == nil) {
            selectedLabelId = nil
        }
    }

    private func labelChip(_ label: AgendaLabel) -> some View {
        chip(title: label.naam, color: Color(hex: label.kleur), active: selectedLabelId == label.id) {
            selectedLabelId = selectedLabelId == label.id ? nil : label.id
        }
    }

    private var newLabelChip: some View {
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
            .padding(.horizontal, BovexaTheme.Space.md)
            .frame(minHeight: 40)
            .background(BovexaTheme.Colors.glass)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1))
        }
        .disabled(disabled)
    }

    private func chip(title: String, color: Color?, active: Bool, onTap: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            onTap()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(color ?? BovexaTheme.Colors.muted.opacity(0.4))
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                    .lineLimit(1)
                if active {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundStyle(active ? BovexaTheme.Colors.white : BovexaTheme.Colors.muted)
            .padding(.horizontal, BovexaTheme.Space.md)
            .frame(minHeight: 40)
            .background(active ? BovexaTheme.Colors.tealDark : BovexaTheme.Colors.glass)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(active ? BovexaTheme.Colors.tealDark : BovexaTheme.Colors.edge, lineWidth: 1))
        }
        .disabled(disabled)
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
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle().strokeBorder(BovexaTheme.Colors.white, lineWidth: newLabelColor == option.hex ? 2.5 : 0)
                        )
                        .overlay(
                            Circle().strokeBorder(BovexaTheme.Colors.edge, lineWidth: newLabelColor == option.hex ? 0 : 1)
                        )
                        .onTapGesture {
                            Haptics.selection()
                            newLabelColor = option.hex
                        }
                }
            }

            Button {
                Task { await createLabel() }
            } label: {
                if isCreating {
                    ProgressView().tint(BovexaTheme.Colors.white)
                } else {
                    Text("Toevoegen")
                        .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                }
            }
            .buttonStyle(.glassProminentBrand)
            .frame(maxWidth: .infinity, minHeight: 42)
            .disabled(isCreating || newLabelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(BovexaTheme.Space.md)
        .background(BovexaTheme.Colors.glassSoft)
        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
    }

    private func createLabel() async {
        let naam = newLabelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !naam.isEmpty else { return }
        isCreating = true
        defer { isCreating = false }
        do {
            let created = try await labelRepository.createLabel(
                org: org, naam: naam, kleur: newLabelColor, volgorde: labelStore.orderedLabels.count, token: token
            )
            labelStore.add(created)
            selectedLabelId = created.id
            newLabelName = ""
            withAnimation(.snappy) { showNewLabelForm = false }
        } catch {
            // Stil falen: gebruiker ziet de nieuwe chip niet verschijnen en kan
            // het opnieuw proberen. Geen apart alert-kanaal voor dit kleine formulier.
        }
    }
}

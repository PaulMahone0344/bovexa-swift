import SwiftUI

/// Bewerkscherm van een afspraak: titel, categorie, datum/tijd/duur-steppers,
/// klant, notitie, herinnering, toewijzen (alleen bij org-afspraak). Vervangt de
/// inhoud van het afspraak-detail — geen apart navigatiescherm.
struct EventEditorView: View {
    @StateObject private var viewModel: EventEditorViewModel
    let members: [Member]
    let onCancel: () -> Void
    let onSaved: (AgendaEvent) -> Void

    private static let categories: [(BovexaTheme.Category, String)] = [
        (.work, "Werk"), (.focus, "Focus"), (.social, "Sociaal"), (.body, "Lichaam"),
    ]

    init(event: AgendaEvent, currentUserId: String, token: String, members: [Member], onCancel: @escaping () -> Void, onSaved: @escaping (AgendaEvent) -> Void) {
        _viewModel = StateObject(wrappedValue: EventEditorViewModel(event: event, token: token))
        self.members = members
        self.onCancel = onCancel
        self.onSaved = onSaved
        self.currentUserId = currentUserId
    }

    private let currentUserId: String

    private var overlapPresented: Binding<Bool> {
        Binding(get: { viewModel.overlapEvent != nil }, set: { if !$0 { viewModel.overlapEvent = nil } })
    }

    var body: some View {
        VStack(spacing: BovexaTheme.Space.lg) {
            GlassCard {
                VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                    fieldLabel("Titel")
                    TextField("Titel", text: $viewModel.title)
                        .textFieldStyle(EditorFieldStyle())

                    fieldLabel("Categorie")
                    chipRow(Self.categories, isActive: { $0 == viewModel.category }) { value in
                        withAnimation(.snappy) { viewModel.category = value }
                    }

                    fieldLabel("Datum")
                    StepperRow(value: EventHelpers.longDay(viewModel.start), onMinus: { viewModel.shiftDay(-1) }, onPlus: { viewModel.shiftDay(1) })

                    fieldLabel("Starttijd")
                    StepperRow(value: EventHelpers.fmtTime(viewModel.start), onMinus: { viewModel.shiftStart(minutes: -15) }, onPlus: { viewModel.shiftStart(minutes: 15) })

                    fieldLabel("Duur")
                    StepperRow(value: "\(viewModel.durationMin) min", onMinus: { viewModel.changeDuration(by: -15) }, onPlus: { viewModel.changeDuration(by: 15) })

                    fieldLabel("Klant (optioneel)")
                    TextField("Naam van de klant", text: $viewModel.klantNaam)
                        .textFieldStyle(EditorFieldStyle())
                    TextField("Telefoon (optioneel)", text: $viewModel.klantTelefoon)
                        .keyboardType(.phonePad)
                        .textFieldStyle(EditorFieldStyle())

                    fieldLabel("Notitie")
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 88)
                        .padding(BovexaTheme.Space.sm)
                        .background(BovexaTheme.Colors.glass)
                        .overlay(
                            RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                                .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))

                    fieldLabel("Herinnering")
                    ReminderChipsView(minutesBefore: $viewModel.reminderMin)

                    if viewModel.originalEvent.org != nil {
                        fieldLabel("Toegewezen aan")
                        AssigneePickerView(members: members, currentUserId: currentUserId, selectedIds: $viewModel.assignee)
                    }
                }
            }

            actions
        }
        .alert("Titel ontbreekt", isPresented: $viewModel.titleMissingAlert) {
            Button("Oké", role: .cancel) {}
        } message: {
            Text("Geef de afspraak een titel.")
        }
        .alert("Mislukt", isPresented: $viewModel.saveFailedAlert) {
            Button("Oké", role: .cancel) {}
        } message: {
            Text("Kon de afspraak niet opslaan.")
        }
        .alert("Dubbele boeking", isPresented: overlapPresented) {
            Button("Aanpassen", role: .cancel) {}
            Button("Toch plannen") {
                Task {
                    if let updated = await viewModel.saveConfirmed() {
                        Haptics.success()
                        onSaved(updated)
                    }
                }
            }
        } message: {
            if let overlap = viewModel.overlapEvent {
                Text("Je staat al \(EventHelpers.fmtTime(overlap.start))–\(EventHelpers.fmtTime(overlap.end)) op \"\(overlap.title)\". Toch plannen?")
            }
        }
    }

    private var actions: some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            Button(action: onCancel) {
                Text("Annuleren")
                    .font(BovexaTheme.TypeStyle.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.glassSecondaryBrand)
            .disabled(viewModel.isSaving)

            Button {
                Task {
                    if let updated = await viewModel.save() {
                        Haptics.success()
                        onSaved(updated)
                    }
                }
            } label: {
                Group {
                    if viewModel.isSaving {
                        ProgressView().tint(BovexaTheme.Colors.white)
                    } else {
                        Text("Opslaan")
                            .font(BovexaTheme.TypeStyle.headline)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.glassProminentBrand)
            .disabled(viewModel.isSaving)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(BovexaTheme.TypeStyle.caption.weight(.bold))
            .foregroundStyle(BovexaTheme.Colors.accent)
            .textCase(.uppercase)
            .tracking(0.3)
    }

    private func chipRow<T: Hashable>(_ items: [(T, String)], isActive: @escaping (T) -> Bool, onSelect: @escaping (T) -> Void) -> some View {
        FlowLayout(spacing: BovexaTheme.Space.xs) {
            ForEach(items, id: \.0) { value, label in
                let active = isActive(value)
                Button {
                    onSelect(value)
                } label: {
                    Text(label)
                        .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                        .foregroundStyle(active ? BovexaTheme.Colors.white : BovexaTheme.Colors.muted)
                        .padding(.horizontal, BovexaTheme.Space.md)
                        .frame(minHeight: 40)
                        .background(active ? BovexaTheme.Colors.tealDark : BovexaTheme.Colors.glass)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(active ? BovexaTheme.Colors.tealDark : BovexaTheme.Colors.edge, lineWidth: 1))
                }
            }
        }
    }
}

private struct EditorFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, BovexaTheme.Space.md)
            .frame(minHeight: 46)
            .foregroundStyle(BovexaTheme.Colors.ink)
            .background(BovexaTheme.Colors.glass)
            .overlay(
                RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                    .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
    }
}

private struct StepperRow: View {
    let value: String
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack {
            Button(action: onMinus) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.accent)
                    .frame(width: 42, height: 42)
            }
            Spacer()
            Text(value)
                .font(BovexaTheme.TypeStyle.headline)
                .foregroundStyle(BovexaTheme.Colors.ink)
            Spacer()
            Button(action: onPlus) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.accent)
                    .frame(width: 42, height: 42)
            }
        }
        .padding(.horizontal, BovexaTheme.Space.xs)
        .frame(minHeight: 46)
        .background(BovexaTheme.Colors.glass)
        .overlay(
            RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
    }
}

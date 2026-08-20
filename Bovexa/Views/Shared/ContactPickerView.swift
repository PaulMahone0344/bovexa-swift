import SwiftUI

/// Contactkiezer (m8): vervangt het losse klantnaam/telefoon-veld in EventEditor en
/// de AI-planner-bevestiging. Kiezen uit je privécontacten, of ter plekke een
/// nieuwe aanmaken (opbouw zoals LabelPickerView). Oude, nog niet gekoppelde tekst
/// blijft zichtbaar als eigen chip (valkuil D) totdat er een echt contact gekozen is.
struct ContactPickerView: View {
    @Binding var selectedContactId: String?
    /// Bestaande losse klantnaam (valkuil D) — alleen om te tonen zolang er geen
    /// contact gekozen is; dit veld wordt hier niet bewerkt.
    let existingKlantNaam: String
    let userId: String
    let token: String
    var contactRepository: ContactRepository = ContactRepository()
    var disabled: Bool = false
    /// Wordt geroepen bij elke keuze, ook bij loslaten (dan met nil). De viewmodel
    /// kopieert naam en telefoon naar klant_naam/klant_telefoon, want een collega
    /// kan het privécontact zelf niet uitlezen en zou anders geen klant zien.
    var onSelect: (AgendaContact?) -> Void = { _ in }

    @State private var contacts: [AgendaContact] = []
    @State private var showNewForm = false
    @State private var newNaam = ""
    @State private var newTelefoon = ""
    @State private var isCreating = false

    private var noneLabel: String {
        existingKlantNaam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Geen contact" : existingKlantNaam
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            FlowLayout(spacing: BovexaTheme.Space.xs) {
                chip(title: noneLabel, active: selectedContactId == nil) {
                    selectedContactId = nil
                    onSelect(nil)
                }
                ForEach(contacts) { contact in
                    chip(title: contact.naam, active: selectedContactId == contact.id) {
                        let losgelaten = selectedContactId == contact.id
                        selectedContactId = losgelaten ? nil : contact.id
                        onSelect(losgelaten ? nil : contact)
                    }
                }
                newContactChip
            }
            if showNewForm {
                newContactForm
            }
        }
        .task { await loadContacts() }
    }

    private func loadContacts() async {
        contacts = (try? await contactRepository.fetchContacts(userId: userId, token: token)) ?? []
    }

    private var newContactChip: some View {
        Button {
            Haptics.selection()
            withAnimation(.snappy) { showNewForm.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("Nieuw contact")
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

    private func chip(title: String, active: Bool, onTap: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            onTap()
        } label: {
            HStack(spacing: 6) {
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
            .background(active ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.glass)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(active ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.edge, lineWidth: 1))
        }
        .disabled(disabled)
    }

    private var newContactForm: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            TextField("Naam", text: $newNaam)
                .padding(.horizontal, BovexaTheme.Space.md)
                .frame(minHeight: 44)
                .background(BovexaTheme.Colors.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                        .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))

            TextField("Telefoon (optioneel)", text: $newTelefoon)
                .keyboardType(.phonePad)
                .padding(.horizontal, BovexaTheme.Space.md)
                .frame(minHeight: 44)
                .background(BovexaTheme.Colors.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                        .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))

            Button {
                Task { await createContact() }
            } label: {
                // Frame ín het label, ook in de ProgressView-tak (M11 patroon A);
                // de minHeight stond buiten de Button en deed daar niets.
                if isCreating {
                    ProgressView().tint(BovexaTheme.Colors.white).frame(maxWidth: .infinity)
                } else {
                    Text("Toevoegen")
                        .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.glassProminentBrand)
            .disabled(isCreating || newNaam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(BovexaTheme.Space.md)
        .background(BovexaTheme.Colors.glassSoft)
        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
    }

    private func createContact() async {
        let naam = newNaam.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !naam.isEmpty else { return }
        isCreating = true
        defer { isCreating = false }
        do {
            let created = try await contactRepository.createContact(
                eigenaar: userId, naam: naam, telefoon: newTelefoon.trimmingCharacters(in: .whitespacesAndNewlines), notitie: "", token: token
            )
            contacts.append(created)
            contacts.sort { $0.naam.localizedCaseInsensitiveCompare($1.naam) == .orderedAscending }
            selectedContactId = created.id
            onSelect(created)
            newNaam = ""
            newTelefoon = ""
            withAnimation(.snappy) { showNewForm = false }
        } catch {
            // Stil falen, zelfde patroon als LabelPickerView.createLabel.
        }
    }
}

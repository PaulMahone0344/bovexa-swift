import SwiftUI

/// Contactkiezer (m8): vervangt het losse klantnaam/telefoon-veld in EventEditor en
/// de AI-planner-bevestiging. Kiezen uit je contacten — meerdere tegelijk mag — of
/// ter plekke een nieuwe aanmaken. De lijst zit achter een samenvattingsrij die
/// open- en dichtklapt (opbouw zoals AssigneePickerView); als losse chips werd de
/// rij bij tien contacten een muur van knoppen. Oude, nog niet gekoppelde tekst
/// blijft zichtbaar in de samenvatting (valkuil D) totdat er een contact gekozen is.
struct ContactPickerView: View {
    /// Gekozen contacten, op volgorde van aantikken. De eerste geldt als de klant
    /// van de afspraak: die naam en dat telefoonnummer gaan mee in klant_naam.
    @Binding var selectedContactIds: [String]
    /// Bestaande losse klantnaam (valkuil D) — alleen om te tonen zolang er geen
    /// contact gekozen is; dit veld wordt hier niet bewerkt.
    let existingKlantNaam: String
    let userId: String
    let token: String
    /// Bedrijf waar deze afspraak bij hoort: leeg = privé. De lijst toont alleen de
    /// contacten uit diezelfde bak. Stond alles door elkaar, dan koos je bij een
    /// privé-afspraak zo een naam van de voetbalschool.
    var org: String = ""
    var contactRepository: ContactRepository = ContactRepository()
    var disabled: Bool = false
    /// Zonder samenvattingsrij: de lijst staat meteen open. Zo gebruikt in de
    /// afspraak-editor, waar de kiezer al onder de knoppen Privé/bedrijf hangt —
    /// een extra rij "Geen contact" met chevron was daar een klik te veel.
    var altijdOpen: Bool = false
    /// Wordt geroepen bij elke wijziging, met alle gekozen contacten op volgorde
    /// (leeg = geen contact). De viewmodel kopieert naam en telefoon van de eerste
    /// naar klant_naam/klant_telefoon, want een collega kan het privécontact zelf
    /// niet uitlezen en zou anders geen klant zien.
    var onSelect: ([AgendaContact]) -> Void = { _ in }

    @State private var contacts: [AgendaContact] = []
    @State private var isOpen = false
    @State private var showNewForm = false
    @State private var newNaam = ""
    @State private var newTelefoon = ""
    @State private var isCreating = false
    @State private var createError: String?
    @State private var loadFailed = false

    /// Zolang de server het veld `org` niet kent staat de indeling lokaal — zelfde
    /// bron als het scherm Mensen (zie MEERDERE-BEDRIJVEN-SERVER.txt, punt 10).
    private let orgStore = ContactOrgStore.shared

    /// Contacten die bij de gekozen zichtbaarheid horen. Een gekozen contact blijft
    /// altijd staan, ook als je daarna van Privé naar het bedrijf wisselt: anders
    /// verdwijnt de naam die er al in stond zonder dat iemand dat vroeg.
    ///
    /// Privé toont ál je contacten, net als het scherm Mensen (besluit 26 augustus:
    /// iedereen staat in je privélijst, ook wie daarnaast bij een bedrijf hoort).
    /// Stond hier de org-filter, dan miste je onder Privé de helft van je eigen
    /// namen zonder dat het scherm vertelde waarom.
    private var zichtbareContacten: [AgendaContact] {
        if org.isEmpty { return contacts }
        return contacts.filter { contact in
            selectedContactIds.contains(contact.id) || orgVan(contact) == org
        }
    }

    private func orgVan(_ contact: AgendaContact) -> String {
        contact.org.isEmpty ? orgStore.org(voor: contact.id) : contact.org
    }

    /// Wat er dichtgeklapt in de rij staat: de gekozen namen, anders de oude losse
    /// klantnaam, anders "Geen contact".
    private var summary: String {
        let namen = selectedContactIds.compactMap { id in contacts.first { $0.id == id }?.naam }
        if !namen.isEmpty { return namen.joined(separator: ", ") }
        if !selectedContactIds.isEmpty { return "\(selectedContactIds.count) gekozen" }
        let los = existingKlantNaam.trimmingCharacters(in: .whitespacesAndNewlines)
        return los.isEmpty ? "Geen contact" : los
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            if !altijdOpen { trigger }
            if altijdOpen || isOpen { uitgeklapteLijst }
            if loadFailed {
                LoadFailedNote(text: "Contacten konden niet worden geladen.")
            }
        }
        .task {
            orgStore.prime(userId: userId)
            await loadContacts()
        }
    }

    private var trigger: some View {
        Button {
            Haptics.selection()
            withAnimation(.snappy) { isOpen.toggle() }
        } label: {
            HStack {
                Text(summary)
                    .font(BovexaTheme.TypeStyle.body.weight(.semibold))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                    .lineLimit(1)
                Spacer()
                Image(systemName: isOpen ? "chevron.up" : "chevron.right")
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }
            .padding(.horizontal, BovexaTheme.Space.md)
            .frame(minHeight: 44)
            .background(BovexaTheme.Colors.glass)
            .overlay(
                RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                    .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
        }
        .disabled(disabled)
    }

    @ViewBuilder
    private var uitgeklapteLijst: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
            // Alleen bij de dichtklapbare variant: daar is het de weg terug naar
            // niets. Staat de lijst altijd open, dan haal je een gekozen contact
            // er weer af door hem nog eens aan te tikken.
            if !altijdOpen {
                contactRij(naam: "Geen contact", gekozen: selectedContactIds.isEmpty) {
                    selectedContactIds = []
                    onSelect([])
                }
            }

            if zichtbareContacten.isEmpty {
                Text(org.isEmpty ? "Nog geen privécontacten." : "Nog geen contacten bij dit bedrijf.")
                    .font(BovexaTheme.TypeStyle.subheadline)
                    .foregroundStyle(BovexaTheme.Colors.muted)
                    .padding(.horizontal, BovexaTheme.Space.md)
            } else {
                ForEach(zichtbareContacten) { contact in
                    contactRij(naam: contact.naam, gekozen: selectedContactIds.contains(contact.id)) {
                        toggle(contact)
                    }
                }
            }

            // "Nieuw contact" stond hier tot 26 augustus. Mensen aanmaken hoort
            // op het Mensen-scherm; hier kies je alleen wie erbij hoort.
        }
    }

    /// Aantikken zet erbij of haalt eraf; de volgorde blijft die van het aantikken,
    /// zodat de eerst gekozen contactpersoon de klant van de afspraak blijft.
    private func toggle(_ contact: AgendaContact) {
        Haptics.selection()
        if selectedContactIds.contains(contact.id) {
            selectedContactIds.removeAll { $0 == contact.id }
        } else {
            selectedContactIds.append(contact.id)
        }
        meldKeuze()
    }

    private func meldKeuze() {
        onSelect(selectedContactIds.compactMap { id in contacts.first { $0.id == id } })
    }

    private func loadContacts() async {
        if let fetched = try? await contactRepository.fetchContacts(userId: userId, token: token) {
            contacts = fetched
            loadFailed = false
        } else {
            // Was stil leeg: je dacht dat je geen contacten hád (4l).
            loadFailed = true
        }
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
            .frame(minHeight: 44)
            .background(BovexaTheme.Colors.glass)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1))
        }
        .disabled(disabled)
    }

    /// Rij met vinkje, zoals bij "Toegewezen aan": het hele blok is de knop, zodat
    /// je niet precies het vakje hoeft te raken.
    private func contactRij(naam: String, gekozen: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: BovexaTheme.Space.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(gekozen ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.glass)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(gekozen ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.edge, lineWidth: 1.5)
                        )
                        .frame(width: 22, height: 22)
                    if gekozen {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(BovexaTheme.Colors.white)
                    }
                }
                Text(naam)
                    .font(BovexaTheme.TypeStyle.body)
                    .foregroundStyle(BovexaTheme.Colors.ink)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, BovexaTheme.Space.md)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
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

            if let createError {
                Text(createError)
                    .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                    .foregroundStyle(BovexaTheme.Colors.danger)
            }
        }
        .padding(BovexaTheme.Space.md)
        .background(BovexaTheme.Colors.glassSoft)
        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
    }

    private func createContact() async {
        let naam = newNaam.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !naam.isEmpty else { return }
        isCreating = true
        createError = nil
        defer { isCreating = false }
        do {
            let created = try await contactRepository.createContact(
                eigenaar: userId, naam: naam, telefoon: newTelefoon.trimmingCharacters(in: .whitespacesAndNewlines),
                notitie: "", org: org.isEmpty ? nil : org, token: token
            )
            // Server geeft `org` nog niet terug; de indeling komt van het toestel.
            orgStore.zet(contactId: created.id, org: org)
            contacts.append(created)
            contacts.sort { $0.naam.localizedCaseInsensitiveCompare($1.naam) == .orderedAscending }
            selectedContactIds.append(created.id)
            meldKeuze()
            Haptics.success()
            newNaam = ""
            newTelefoon = ""
            withAnimation(.snappy) { showNewForm = false }
        } catch {
            Haptics.warning()
            createError = "Kon het contact niet aanmaken. Probeer het opnieuw."
        }
    }
}

import SwiftUI

/// Formulier van een afspraak: titel, categorie, label, datum/tijd/duur-steppers,
/// contact, notitie, herinnering, toewijzen (alleen bij org-afspraak). Twee modi:
///  - bewerken — vervangt de inhoud van het afspraak-detail, geen apart scherm;
///  - aanmaken (M12) — hetzelfde formulier met een voorzet, plus zichtbaarheid
///    (bij bewerken zit die in het detail; bij aanmaken zou een nieuwe afspraak
///    anders ongemerkt altijd op "privé" staan) en de knop "Toevoegen".
struct EventEditorView: View {
    @FocusState private var notesFocused: Bool
    @StateObject private var eigenCategorieen = EigenCategorieStore.shared
    /// Welke eigen categorie aangetikt is. Los van `viewModel.category`, want de
    /// server kent alleen de vaste waarde eronder — de naam leeft in dit scherm.
    @State private var gekozenEigenCategorie: String?
    @State private var toonNieuweCategorie = false
    @State private var nieuweCategorieNaam = ""
    @StateObject private var viewModel: EventEditorViewModel
    @ObservedObject var labelStore: LabelStore
    let members: [Member]
    let onCancel: () -> Void
    let onSaved: (AgendaEvent) -> Void

    /// Vaste categorieën. De onderliggende waarden blijven wat ze waren, zodat
    /// bestaande afspraken hun kleur en icoon houden; alleen het opschrift is
    /// veranderd (Sociaal ⇒ Familie, Lichaam ⇒ Sport). `.focus` staat niet meer
    /// als vaste knop in de rij: die waarde draagt nu de eigen categorieën.
    private static let categories: [(BovexaTheme.Category, String)] = [
        (.work, "Werk"), (.social, "Familie"), (.body, "Sport"),
    ]

    /// Vaste waarde waaronder een zelfbedachte categorie naar de server gaat.
    private static let eigenCategorieWaarde: BovexaTheme.Category = .focus

    init(
        event: AgendaEvent, currentUserId: String, token: String, members: [Member], labelStore: LabelStore,
        onCancel: @escaping () -> Void, onSaved: @escaping (AgendaEvent) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: EventEditorViewModel(event: event, token: token))
        self.labelStore = labelStore
        self.members = members
        self.onCancel = onCancel
        self.onSaved = onSaved
        self.currentUserId = currentUserId
        self.token = token
        self.org = event.org ?? ""
        self.companyName = ""
    }

    /// Aanmaken (M12): zelfde formulier, gevuld vanuit de voorzet. `org` leeg ⇒ geen
    /// bedrijf, dus geen zichtbaarheidskeuze, geen label en geen toewijzen.
    init(
        seed: NieuweAfspraakSeed, currentUserId: String, org: String, companyName: String, token: String,
        members: [Member], labelStore: LabelStore,
        defaultDurationMin: Int = EventEditorViewModel.fallbackDurationMin,
        onCancel: @escaping () -> Void, onSaved: @escaping (AgendaEvent) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: EventEditorViewModel(
            mode: .create(seed), ownerId: currentUserId, org: org, token: token,
            defaultDurationMin: defaultDurationMin
        ))
        self.labelStore = labelStore
        self.members = members
        self.onCancel = onCancel
        self.onSaved = onSaved
        self.currentUserId = currentUserId
        self.token = token
        self.org = org
        self.companyName = companyName
    }

    private let currentUserId: String
    private let token: String
    private let org: String
    private let companyName: String

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
                    categorieChips

                    if !org.isEmpty {
                        fieldLabel("Label")
                        LabelPickerView(labelStore: labelStore, selectedLabelId: $viewModel.label, org: org, token: token)
                    }

                    fieldLabel("Datum")
                    StepperRow(value: EventHelpers.longDay(viewModel.start), minusLabel: "Dag eerder", plusLabel: "Dag later", onMinus: { viewModel.shiftDay(-1) }, onPlus: { viewModel.shiftDay(1) })

                    fieldLabel("Starttijd")
                    StepperRow(value: EventHelpers.fmtTime(viewModel.start), minusLabel: "Kwartier eerder", plusLabel: "Kwartier later", onMinus: { viewModel.shiftStart(minutes: -15) }, onPlus: { viewModel.shiftStart(minutes: 15) })

                    fieldLabel("Duur")
                    StepperRow(value: "\(viewModel.durationMin) min", minusLabel: "Kwartier korter", plusLabel: "Kwartier langer", onMinus: { viewModel.changeDuration(by: -15) }, onPlus: { viewModel.changeDuration(by: 15) })

                    fieldLabel("Contact (optioneel)")
                    ContactPickerView(
                        selectedContactId: $viewModel.contactId,
                        existingKlantNaam: viewModel.klantNaam,
                        userId: currentUserId, token: token,
                        onSelect: { viewModel.selectContact($0) }
                    )

                    fieldLabel("Notitie")
                    TextEditor(text: $viewModel.notes)
                        .keyboardDone(focused: $notesFocused)
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

                    // PocketBase geeft een lege relatie terug als "", niet als null:
                    // vandaar `!org.isEmpty` en geen nil-check. Zelfde conditie als
                    // de labelkiezer hierboven.
                    if !org.isEmpty {
                        fieldLabel("Toegewezen aan")
                        AssigneePickerView(members: members, currentUserId: currentUserId, selectedIds: $viewModel.assignee)
                    }
                }
            }

            // Alleen bij aanmaken én met een bedrijf: zonder bedrijf is er niets te
            // kiezen (alles is privé), en bij bewerken staat de keuze in het detail.
            if viewModel.isCreating && !org.isEmpty {
                VisibilityPickerView(value: viewModel.visibility, companyName: companyName.isEmpty ? "Bedrijf" : companyName) { value in
                    viewModel.visibility = value
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
                        Text(viewModel.isCreating ? "Toevoegen" : "Opslaan")
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

    /// Vaste categorieën, daarna de zelfbedachte, en "Anders" altijd als laatste.
    /// Een nieuwe eigen categorie komt er dus links naast te staan.
    private var categorieChips: some View {
        FlowLayout(spacing: BovexaTheme.Space.xs) {
            ForEach(Self.categories, id: \.0) { value, label in
                categorieChip(label, actief: gekozenEigenCategorie == nil && viewModel.category == value) {
                    withAnimation(.snappy) {
                        viewModel.category = value
                        gekozenEigenCategorie = nil
                    }
                }
            }

            ForEach(eigenCategorieen.namen, id: \.self) { naam in
                categorieChip(naam, actief: gekozenEigenCategorie == naam) {
                    withAnimation(.snappy) {
                        viewModel.category = Self.eigenCategorieWaarde
                        gekozenEigenCategorie = naam
                    }
                }
                // Weghalen kan alleen hier: een kruisje op elke chip zou de rij
                // laten struikelen en per ongeluk-tikken uitlokken.
                .contextMenu {
                    Button("Verwijderen", role: .destructive) {
                        if gekozenEigenCategorie == naam {
                            gekozenEigenCategorie = nil
                            viewModel.category = Self.categories[0].0
                        }
                        eigenCategorieen.verwijder(naam)
                    }
                }
            }

            categorieChip("Anders", actief: false, systemImage: "plus") {
                nieuweCategorieNaam = ""
                toonNieuweCategorie = true
            }
            .disabled(eigenCategorieen.namen.count >= EigenCategorieStore.maxAantal)
        }
        .alert("Eigen categorie", isPresented: $toonNieuweCategorie) {
            TextField("Naam", text: $nieuweCategorieNaam)
                .textInputAutocapitalization(.words)
            Button("Annuleren", role: .cancel) {}
            Button("Opslaan") { bewaarEigenCategorie() }
        } message: {
            Text("De naam blijft als knop staan, alleen op dit toestel.")
        }
    }

    private func categorieChip(_ label: String, actief: Bool, systemImage: String? = nil, actie: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            actie()
        } label: {
            HStack(spacing: BovexaTheme.Space.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                }
                Text(label)
                    .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
            }
            .foregroundStyle(actief ? BovexaTheme.Colors.white : BovexaTheme.Colors.muted)
            .padding(.horizontal, BovexaTheme.Space.md)
            .frame(minHeight: 44)
            .background(actief ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.glass)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(actief ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.edge, lineWidth: 1))
        }
    }

    /// Opslaan én meteen selecteren: je tikt "Anders" aan omdat je die categorie
    /// nu nodig hebt, niet om een lijstje te vullen.
    private func bewaarEigenCategorie() {
        guard let bewaard = eigenCategorieen.voegToe(nieuweCategorieNaam) else { return }
        withAnimation(.snappy) {
            viewModel.category = Self.eigenCategorieWaarde
            gekozenEigenCategorie = bewaard
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
    /// Drie steppers op één scherm; zonder eigen labels leest VoiceOver hier
    /// drie identieke "Back/Forward"-paren voor.
    let minusLabel: String
    let plusLabel: String
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack {
            Button(action: onMinus) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.accent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(minusLabel)
            Spacer()
            Text(value)
                .font(BovexaTheme.TypeStyle.headline)
                .foregroundStyle(BovexaTheme.Colors.ink)
            Spacer()
            Button(action: onPlus) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.accent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(plusLabel)
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

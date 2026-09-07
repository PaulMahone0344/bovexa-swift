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
    @State private var nieuweCategorieKleur = BovexaTheme.LabelPalette.options[0].hex
    @State private var categorieBezig = false
    @State private var categorieFout: String?
    /// Welke bestaande knop bewerkt wordt (label, kleur, weghalen). Los van
    /// `toonNieuweCategorie`, dat is het formulier voor een nieuwe knop.
    @State private var bewerkCategorie: String?
    /// Welke van de drie rijen zijn kiezer open heeft — er past er maar één
    /// tegelijk op het scherm.
    @State private var toonKiezerVoor: TijdVeld?
    /// Notitieveld staat dicht tot je erom vraagt: het grote lege vak maakte het
    /// formulier een half scherm langer terwijl de meeste afspraken geen
    /// notitie hebben. Met een bestaande notitie staat het meteen open.
    @State private var notitieOpen = false
    private let labelRepository = LabelRepository()
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
        // Bedrijfsnaam voor de zichtbaarheidsknop; zonder stond hier "Bedrijf"
        // terwijl het detail eromheen "Bovexa.nl" zei.
        companyName: String = "",
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
        self.companyName = companyName
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

                    // Labelrij weggehaald op verzoek: de categorieknoppen dekken dit al,
                    // en bij een bedrijf maakt "Label geven…" op zo'n knop het label aan.
                    // viewModel.label blijft bestaan zodat een bestaand label niet wist.

                    // Datum, start en eind op één rij (7 sep): drie losse
                    // stepper-rijen met elk een kopje maakten het formulier twee
                    // schermen hoog. Tik op een pil opent de kiezer eronder.
                    fieldLabel("Wanneer")
                    wanneerRij
                    if toonKiezerVoor == .datum {
                        DatePicker("Datum", selection: datumBinding, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .tint(BovexaTheme.Colors.accent)
                    } else if toonKiezerVoor == .start {
                        tijdKiezer(selection: startBinding)
                    } else if toonKiezerVoor == .eind {
                        tijdKiezer(selection: eindBinding)
                    }

                    // Zodra er een bedrijf is: zonder bedrijf valt er niets te
                    // kiezen (alles is privé). Ook bij bewerken, want wie een
                    // afspraak aanpast verwacht deze knoppen op dezelfde plek als
                    // bij het maken. Staat tussen tijd en contact, want wie het mag
                    // zien bepaalt ook welke contacten passen.
                    if !org.isEmpty {
                        VisibilityPickerView(value: viewModel.visibility, companyName: companyName.isEmpty ? "Bedrijf" : companyName) { value in
                            viewModel.visibility = value
                        }

                        // De lijst hangt onder de knoppen in plaats van in een eigen
                        // "Contact (optioneel)"-rij: wie je kunt aanwijzen hangt af
                        // van de keuze erboven, dus tikken op Privé of het bedrijf
                        // wisselt meteen de namen eronder. Dezelfde indeling als op
                        // het scherm Mensen: privé zijn je contacten, het bedrijf
                        // zijn de collega's met een account. Stonden je privénamen
                        // onder de bedrijfsknop, dan deelde je een afspraak met
                        // iemand die er helemaal niet bij werkt.
                        if viewModel.visibility == "private" {
                            contactKiezer
                                .padding(.horizontal, BovexaTheme.Space.md)
                        } else {
                            MemberChecklistView(
                                members: members,
                                currentUserId: currentUserId,
                                selectedIds: $viewModel.assignee
                            )
                            .padding(.horizontal, BovexaTheme.Space.md)
                        }
                    } else {
                        fieldLabel("Contact (optioneel)")
                        contactKiezer
                    }

                    if notitieOpen || !viewModel.notes.isEmpty {
                        fieldLabel("Notitie")
                        TextEditor(text: $viewModel.notes)
                        // Geen "Klaar"-knop boven het toetsenbord: die bleef in de
                        // sheet over "Toevoegen" hangen. Het toetsenbord gaat weg
                        // door te scrollen (scrollDismissesKeyboard in de sheet).
                        .focused($notesFocused)
                        .frame(minHeight: 88)
                        .padding(BovexaTheme.Space.sm)
                        .background(BovexaTheme.Colors.glass)
                        .overlay(
                            RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                                .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
                    } else {
                        Button {
                            Haptics.selection()
                            withAnimation(.snappy(duration: 0.22)) { notitieOpen = true }
                            notesFocused = true
                        } label: {
                            Label("Notitie toevoegen", systemImage: "plus")
                                .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                                .foregroundStyle(BovexaTheme.Colors.accent)
                                .frame(minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Kopje en chips op één regel: de chips scrollen toch al
                    // horizontaal, dus het kopje erboven kostte alleen hoogte.
                    HStack(alignment: .center, spacing: BovexaTheme.Space.sm) {
                        fieldLabel("Herinnering")
                        ReminderChipsView(minuten: $viewModel.reminderMinuten)
                    }

                    // "Toegewezen aan" stond hier ook nog: bij een afspraak bepaalt
                    // de zichtbaarheid al wie hem ziet, en het contact wie het
                    // betreft. Toewijzen hoort bij dagtaken.
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

    /// Eén definitie voor beide plekken (onder de zichtbaarheidknoppen of als
    /// eigen rij zonder bedrijf), zodat ze niet uit elkaar kunnen lopen.
    private var contactKiezer: some View {
        ContactPickerView(
            selectedContactIds: $viewModel.contactIds,
            existingKlantNaam: viewModel.klantNaam,
            userId: currentUserId, token: token,
            // Privé toont privécontacten, het bedrijf de zijne.
            org: viewModel.visibility == "private" ? "" : org,
            altijdOpen: true,
            onSelect: { viewModel.selectContacts($0) }
        )
    }

    private enum TijdVeld { case datum, start, eind }

    /// Datum · start → eind als drie pillen. De open pil kleurt blauw, zodat te
    /// zien is welke kiezer eronder hoort.
    private var wanneerRij: some View {
        HStack(spacing: BovexaTheme.Space.xs) {
            // Tijd-pillen houden hun eigen breedte; de datum krijgt wat overblijft.
            tijdPil(EventHelpers.shortDay(viewModel.start), veld: .datum, label: "Datum, \(EventHelpers.longDay(viewModel.start))")
            tijdPil(EventHelpers.fmtTime(viewModel.start), veld: .start, label: "Starttijd \(EventHelpers.fmtTime(viewModel.start))")
                .fixedSize(horizontal: true, vertical: false)
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BovexaTheme.Colors.inkSoft)
                .accessibilityHidden(true)
            tijdPil(EventHelpers.fmtTime(viewModel.end), veld: .eind, label: "Eindtijd \(EventHelpers.fmtTime(viewModel.end))")
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func tijdPil(_ tekst: String, veld: TijdVeld, label: String) -> some View {
        let actief = toonKiezerVoor == veld
        return Button {
            Haptics.selection()
            toonKiezer(veld)
        } label: {
            Text(tekst)
                .font(BovexaTheme.TypeStyle.headline)
                .foregroundStyle(actief ? BovexaTheme.Colors.white : BovexaTheme.Colors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, BovexaTheme.Space.sm)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(actief ? AnyShapeStyle(BovexaTheme.Colors.accent) : AnyShapeStyle(BovexaTheme.Colors.glass))
                .overlay(
                    RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                        .strokeBorder(BovexaTheme.Colors.edge, lineWidth: actief ? 0 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint("Opent de kiezer")
    }

    private func toonKiezer(_ veld: TijdVeld) {
        withAnimation(.snappy(duration: 0.22)) {
            toonKiezerVoor = toonKiezerVoor == veld ? nil : veld
        }
    }

    private var datumBinding: Binding<Date> {
        Binding(get: { viewModel.start }, set: { viewModel.setStart($0) })
    }

    private var startBinding: Binding<Date> {
        Binding(get: { viewModel.start }, set: { viewModel.setStart($0) })
    }

    private var eindBinding: Binding<Date> {
        Binding(get: { viewModel.end }, set: { viewModel.setEnd($0) })
    }

    /// Wielen in plaats van het compacte klokje: die opent nog een popover,
    /// terwijl dit meteen onder de rij staat waar je op tikte.
    /// Het wiel met een knop eronder. Zonder die knop bleef het wiel openstaan en
    /// was niet te zien dat de tijd al was overgenomen — die staat immers meteen in
    /// de rij erboven. "Klaar" klapt het wiel dicht en laat de rest van het
    /// formulier weer zien.
    private func tijdKiezer(selection: Binding<Date>) -> some View {
        VStack(spacing: BovexaTheme.Space.sm) {
            DatePicker("Tijd", selection: selection, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                Button("Klaar") {
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.22)) { toonKiezerVoor = nil }
                }
                .buttonStyle(.glassProminentBrand)
            }
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
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            categorieRij
            if toonNieuweCategorie { nieuweCategorieForm }
            if let bewerkCategorie { categorieBewerkForm(bewerkCategorie) }
        }
    }

    private var categorieRij: some View {
        FlowLayout(spacing: BovexaTheme.Space.xs) {
            // Niet elke afspraak is werk, familie of sport; "Leeg" laat de categorie
            // weg in plaats van er een te moeten verzinnen.
            categorieChip("Leeg", actief: viewModel.category == nil && gekozenEigenCategorie == nil) {
                withAnimation(.snappy) {
                    viewModel.category = nil
                    gekozenEigenCategorie = nil
                }
            }

            ForEach(Self.categories.filter { !eigenCategorieen.isVerborgen($0.1) }, id: \.0) { value, label in
                let actief = gekozenEigenCategorie == nil && viewModel.category == value
                categorieChip(label, actief: actief, kleur: labelKleur(voor: label)) {
                    // Tweede tik op een knop die al aanstaat opent het paneel —
                    // zo is bewerken ook zonder lang drukken te vinden.
                    if actief {
                        openCategorieBewerken(label)
                    } else {
                        withAnimation(.snappy) {
                            viewModel.category = value
                            gekozenEigenCategorie = nil
                        }
                    }
                }
                .contextMenu { categorieMenu(label) }
            }

            ForEach(eigenCategorieen.namen, id: \.self) { naam in
                let actief = gekozenEigenCategorie == naam
                categorieChip(naam, actief: actief, kleur: eigenCategorieen.kleur(voor: naam).map { Color(hex: $0) } ?? labelKleur(voor: naam)) {
                    if actief {
                        openCategorieBewerken(naam)
                    } else {
                        withAnimation(.snappy) {
                            viewModel.category = Self.eigenCategorieWaarde
                            gekozenEigenCategorie = naam
                        }
                    }
                }
                .contextMenu { categorieMenu(naam) }
            }

            categorieChip("Anders", actief: false, systemImage: "plus") {
                if !toonNieuweCategorie {
                    nieuweCategorieNaam = ""
                    nieuweCategorieKleur = BovexaTheme.LabelPalette.options[0].hex
                    categorieFout = nil
                }
                withAnimation(.snappy) { toonNieuweCategorie.toggle() }
            }
            .disabled(eigenCategorieen.namen.count >= EigenCategorieStore.maxAantal)
        }
    }

    /// Vroeger een alert met alleen een naamveld. Een categorie zonder kleur is
    /// in de agenda niet terug te vinden, dus staat de kleurkeuze er nu direct
    /// onder — en bij een bedrijf komt er meteen een label van, want dat is wat
    /// de afspraak in de agenda daadwerkelijk kleurt.
    private var nieuweCategorieForm: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            TextField("Naam", text: $nieuweCategorieNaam)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, BovexaTheme.Space.md)
                .frame(minHeight: 44)
                .background(BovexaTheme.Colors.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                        .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))

            kleurRij

            // Weggehaalde vaste knoppen zijn hier terug te halen; anders zijn ze
            // na één tik in het menu voorgoed weg.
            if !eigenCategorieen.verborgenVast.isEmpty {
                VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
                    Text("Weggehaalde knoppen")
                        .font(BovexaTheme.TypeStyle.footnote.weight(.bold))
                        .foregroundStyle(BovexaTheme.Colors.muted)
                    FlowLayout(spacing: BovexaTheme.Space.xs) {
                        ForEach(Self.categories.map(\.1).filter { eigenCategorieen.isVerborgen($0) }, id: \.self) { naam in
                            categorieChip(naam, actief: false, systemImage: "arrow.uturn.backward") {
                                withAnimation(.snappy) { eigenCategorieen.herstelVast(naam) }
                            }
                        }
                    }
                }
            }

            if let categorieFout {
                Text(categorieFout)
                    .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                    .foregroundStyle(BovexaTheme.Colors.danger)
            }

            Text(org.isEmpty
                 ? "De knop blijft staan, alleen op dit toestel."
                 : "Er komt ook een label met deze naam en kleur, voor iedereen in het bedrijf.")
                .font(BovexaTheme.TypeStyle.footnote)
                .foregroundStyle(BovexaTheme.Colors.muted)

            HStack(spacing: BovexaTheme.Space.sm) {
                Button("Annuleren") {
                    withAnimation(.snappy) { toonNieuweCategorie = false }
                }
                .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                .foregroundStyle(BovexaTheme.Colors.muted)

                Button {
                    Task { await bewaarEigenCategorie() }
                } label: {
                    Text(categorieBezig ? "Bezig…" : "Toevoegen")
                        .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                        .foregroundStyle(BovexaTheme.Colors.white)
                        .padding(.horizontal, BovexaTheme.Space.lg)
                        .frame(minHeight: 44)
                        .background(BovexaTheme.Colors.blueDeep)
                        .clipShape(Capsule())
                }
                .disabled(categorieBezig || nieuweCategorieNaam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(BovexaTheme.Space.md)
        .background(BovexaTheme.Colors.glass)
        .overlay(
            RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
    }

    /// Menu achter lang drukken. Zelfde inhoud voor vaste en eigen knoppen: een
    /// label geven of aanpassen, en de knop weghalen.
    @ViewBuilder
    private func categorieMenu(_ naam: String) -> some View {
        Button(label(voor: naam) == nil ? "Label geven…" : "Label aanpassen…") {
            openCategorieBewerken(naam)
        }
        Button("Knop verwijderen", role: .destructive) {
            verwijderCategorieKnop(naam)
        }
    }

    /// Paneel achter een tweede tik of lang drukken: naam, kleur, weghalen.
    private func categorieBewerkForm(_ categorie: String) -> some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            Text(label(voor: categorie) == nil ? "Label voor \(categorie)" : "Label aanpassen")
                .font(BovexaTheme.TypeStyle.footnote.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.muted)

            TextField("Naam", text: $nieuweCategorieNaam)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, BovexaTheme.Space.md)
                .frame(minHeight: 44)
                .background(BovexaTheme.Colors.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                        .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))

            kleurRij

            if let categorieFout {
                Text(categorieFout)
                    .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                    .foregroundStyle(BovexaTheme.Colors.danger)
            }

            if org.isEmpty {
                Text("Zonder bedrijf blijft het bij de kleur van de knop.")
                    .font(BovexaTheme.TypeStyle.footnote)
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }

            HStack(spacing: BovexaTheme.Space.sm) {
                Button("Annuleren") {
                    withAnimation(.snappy) { bewerkCategorie = nil }
                }
                .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                .foregroundStyle(BovexaTheme.Colors.muted)

                Button("Knop verwijderen", role: .destructive) {
                    verwijderCategorieKnop(categorie)
                }
                .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))

                Spacer(minLength: 0)

                Button {
                    Task { await bewaarCategorieLabel(categorie) }
                } label: {
                    Text(categorieBezig ? "Bezig…" : "Opslaan")
                        .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                        .foregroundStyle(BovexaTheme.Colors.white)
                        .padding(.horizontal, BovexaTheme.Space.lg)
                        .frame(minHeight: 44)
                        .background(BovexaTheme.Colors.blueDeep)
                        .clipShape(Capsule())
                }
                .disabled(categorieBezig || nieuweCategorieNaam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(BovexaTheme.Space.md)
        .background(BovexaTheme.Colors.glass)
        .overlay(
            RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
    }

    private var kleurRij: some View {
        FlowLayout(spacing: 0) {
            ForEach(BovexaTheme.LabelPalette.options) { option in
                let isCurrent = nieuweCategorieKleur == option.hex
                Button {
                    Haptics.selection()
                    nieuweCategorieKleur = option.hex
                } label: {
                    Circle()
                        .fill(Color(hex: option.hex))
                        .frame(width: 26, height: 26)
                        .overlay(Circle().strokeBorder(BovexaTheme.Colors.white, lineWidth: isCurrent ? 2.5 : 0))
                        .overlay(Circle().strokeBorder(BovexaTheme.Colors.edge, lineWidth: isCurrent ? 0 : 1))
                        .minTapTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.name)
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
            }
        }
    }

    /// Het label dat bij een categorienaam hoort. De koppeling loopt via de naam:
    /// de server kent geen verband tussen categorie en label.
    private func label(voor categorie: String) -> AgendaLabel? {
        labelStore.orderedLabels.first { $0.naam.caseInsensitiveCompare(categorie) == .orderedSame }
    }

    private func labelKleur(voor categorie: String) -> Color? {
        label(voor: categorie).map { Color(hex: $0.kleur) }
    }

    private func openCategorieBewerken(_ naam: String) {
        let bestaand = label(voor: naam)
        nieuweCategorieNaam = bestaand?.naam ?? naam
        nieuweCategorieKleur = bestaand?.kleur
            ?? eigenCategorieen.kleur(voor: naam)
            ?? BovexaTheme.LabelPalette.options[0].hex
        categorieFout = nil
        toonNieuweCategorie = false
        withAnimation(.snappy) { bewerkCategorie = naam }
    }

    /// Weghalen: een eigen knop verdwijnt, een vaste wordt verborgen — de waarde
    /// blijft bestaan, zodat oude afspraken hun categorie houden.
    private func verwijderCategorieKnop(_ naam: String) {
        Haptics.warning()
        if gekozenEigenCategorie == naam {
            gekozenEigenCategorie = nil
            viewModel.category = nil
        } else if let vast = Self.categories.first(where: { $0.1 == naam }), viewModel.category == vast.0 {
            viewModel.category = nil
        }
        withAnimation(.snappy) {
            if eigenCategorieen.namen.contains(naam) {
                eigenCategorieen.verwijder(naam)
            } else {
                eigenCategorieen.verbergVast(naam)
            }
            bewerkCategorie = nil
        }
    }

    private func bewaarCategorieLabel(_ categorie: String) async {
        categorieFout = nil
        let naam = nieuweCategorieNaam.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !naam.isEmpty else { return }

        // Eigen knop: naam en kleur van de knop zelf gaan mee, anders wijst de
        // knop straks naar een label dat anders heet.
        if eigenCategorieen.namen.contains(categorie) {
            if naam.caseInsensitiveCompare(categorie) != .orderedSame,
               let hernoemd = eigenCategorieen.hernoem(categorie, naar: naam) {
                if gekozenEigenCategorie == categorie { gekozenEigenCategorie = hernoemd }
            }
            eigenCategorieen.zetKleur(nieuweCategorieKleur, voor: gekozenEigenCategorie ?? naam)
        }

        guard !org.isEmpty, !token.isEmpty else {
            withAnimation(.snappy) { bewerkCategorie = nil }
            return
        }

        categorieBezig = true
        defer { categorieBezig = false }
        do {
            if let bestaand = label(voor: categorie) {
                var bijgewerkt = bestaand
                if naam != bestaand.naam {
                    bijgewerkt = try await labelRepository.renameLabel(id: bestaand.id, naam: naam, token: token)
                }
                if nieuweCategorieKleur != bestaand.kleur {
                    bijgewerkt = try await labelRepository.updateColor(id: bestaand.id, kleur: nieuweCategorieKleur, token: token)
                }
                labelStore.update(bijgewerkt)
                viewModel.label = bijgewerkt.id
            } else {
                let nieuw = try await labelRepository.createLabel(
                    org: org, naam: naam, kleur: nieuweCategorieKleur,
                    volgorde: labelStore.orderedLabels.count, token: token
                )
                labelStore.add(nieuw)
                viewModel.label = nieuw.id
            }
            Haptics.success()
            withAnimation(.snappy) { bewerkCategorie = nil }
        } catch {
            categorieFout = "Kon het label niet opslaan."
        }
    }

    private func categorieChip(_ label: String, actief: Bool, systemImage: String? = nil, kleur: Color? = nil, actie: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            actie()
        } label: {
            HStack(spacing: BovexaTheme.Space.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                }
                if let kleur {
                    Circle()
                        .fill(kleur)
                        .frame(width: 10, height: 10)
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
    private func bewaarEigenCategorie() async {
        categorieFout = nil
        guard let bewaard = eigenCategorieen.voegToe(nieuweCategorieNaam, kleur: nieuweCategorieKleur) else {
            categorieFout = eigenCategorieen.bestaat(nieuweCategorieNaam)
                ? "Die naam staat er al."
                : "Er passen er niet meer bij."
            return
        }
        withAnimation(.snappy) {
            viewModel.category = Self.eigenCategorieWaarde
            gekozenEigenCategorie = bewaard
            toonNieuweCategorie = false
        }

        // Zonder bedrijf bestaan er geen labels; dan blijft het bij de knop.
        guard !org.isEmpty, !token.isEmpty else { return }
        categorieBezig = true
        defer { categorieBezig = false }
        do {
            let label = try await labelRepository.createLabel(
                org: org,
                naam: bewaard,
                kleur: nieuweCategorieKleur,
                volgorde: labelStore.orderedLabels.count,
                token: token
            )
            labelStore.add(label)
            viewModel.label = label.id
        } catch {
            // De categorieknop staat er wel; alleen het label ontbreekt.
            categorieFout = "De knop staat er, maar het label kon niet worden aangemaakt."
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


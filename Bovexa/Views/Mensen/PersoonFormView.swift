import SwiftUI

/// Formulier voor een privécontact: aanmaken of wijzigen/verwijderen (m8). Alleen
/// naam, telefoon en notitie — geen account, geen koppeling (valkuil B).
struct PersoonFormView: View {
    enum Mode {
        case add
        case edit(AgendaContact)
    }

    /// Wat er nodig is om de afspraken van deze persoon op te halen. Nil laat het
    /// inzet-overzicht weg — bij "Persoon toevoegen" bestaat er nog niets om te tonen.
    struct InzetBron {
        let userId: String
        let orgId: String?
        let token: String
    }

    let mode: Mode
    /// Waar de nieuwe persoon terechtkomt ("Privé" of de bedrijfsnaam). Staat als
    /// regel boven het formulier, zodat je na het aantikken van een van de twee
    /// plusknoppen nog ziet welke je had.
    var doelNaam: String?
    let onSave: (String, String, String) async -> Bool
    var onDelete: (() async -> Void)?
    /// De foutmelding stond als `.alert` op MensenView, ónder deze sheet — SwiftUI
    /// presenteert die dan niet: de spinner flitste en er gebeurde niets. De tekst
    /// hoort hier, bij de knop die faalde.
    var errorText: String?
    var inzetBron: InzetBron?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var inzet = PersoonInzetViewModel()
    @State private var naam: String
    @State private var telefoon: String
    @State private var notitie: String
    @State private var saving = false
    @State private var showDeleteConfirm = false

    init(
        mode: Mode,
        doelNaam: String? = nil,
        onSave: @escaping (String, String, String) async -> Bool,
        onDelete: (() async -> Void)? = nil,
        errorText: String? = nil,
        inzetBron: InzetBron? = nil
    ) {
        self.mode = mode
        self.doelNaam = doelNaam
        self.onSave = onSave
        self.onDelete = onDelete
        self.errorText = errorText
        self.inzetBron = inzetBron
        switch mode {
        case .add:
            _naam = State(initialValue: "")
            _telefoon = State(initialValue: "")
            _notitie = State(initialValue: "")
        case .edit(let contact):
            _naam = State(initialValue: contact.naam)
            _telefoon = State(initialValue: contact.telefoon)
            _notitie = State(initialValue: contact.notitie)
        }
    }

    private var title: String {
        switch mode {
        case .add: return "Persoon toevoegen"
        case .edit: return "Persoon wijzigen"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: BovexaTheme.Space.md) {
                        if let doelNaam {
                            Text("Komt bij: \(doelNaam)")
                                .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                                .foregroundStyle(BovexaTheme.Colors.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                                field(label: "Naam", text: $naam, keyboard: .default)
                                field(label: "Telefoon", text: $telefoon, keyboard: .phonePad)
                                field(label: "Notitie", text: $notitie, keyboard: .default)
                            }
                        }

                        if let errorText {
                            Text(errorText)
                                .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                                .foregroundStyle(BovexaTheme.Colors.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if case .edit(let contact) = mode, let bron = inzetBron {
                            inzetKaart
                                .task(id: contact.id) {
                                    await inzet.load(
                                        contact: contact, userId: bron.userId,
                                        orgId: bron.orgId, token: bron.token
                                    )
                                }
                        }

                        // Geen onDelete betekent: dit contact is niet van jou
                        // (bedrijfscontact van een collega). Dan hoort de knop er
                        // ook niet te staan.
                        if case .edit = mode, onDelete != nil {
                            // Frame ín het label, kleur uit de stijl: buiten de
                            // Button deden breedte, font en kleur niets (M11 1c).
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Text("Verwijderen").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassSecondaryDanger)
                        }
                    }
                    .padding(BovexaTheme.Space.xl)
                }
                // Naar beneden vegen sluit het toetsenbord; anders bleef het staan
                // over de knoppen heen.
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuleren") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if saving {
                        ProgressView()
                    } else {
                        // "Opslaan" zoals overal elders in de app; uit zolang er
                        // geen naam staat, in plaats van stil falen op de server.
                        Button("Opslaan") { Task { await save() } }
                            .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                            .disabled(naam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .alert("Contact verwijderen?", isPresented: $showDeleteConfirm) {
                Button("Annuleren", role: .cancel) {}
                Button("Verwijderen", role: .destructive) {
                    Task {
                        await onDelete?()
                        dismiss()
                    }
                }
            } message: {
                Text("Dit contact wordt definitief verwijderd.")
            }
        }
    }

    /// Uren en dagen van deze persoon. Alles komt uit de agenda (ContactInzet) —
    /// er valt hier niets in te vullen, het is een overzicht.
    private var inzetKaart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                Text("INGEPLAND")
                    .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                    .foregroundStyle(BovexaTheme.Colors.accent)

                if inzet.loading {
                    ProgressView().tint(BovexaTheme.Colors.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if inzet.loadFailed {
                    Text("Kon de afspraken niet laden.")
                        .font(BovexaTheme.TypeStyle.footnote)
                        .foregroundStyle(BovexaTheme.Colors.danger)
                } else if inzet.regels.isEmpty {
                    Text("Deze persoon staat nergens ingepland.")
                        .font(BovexaTheme.TypeStyle.footnote)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                } else {
                    HStack(spacing: BovexaTheme.Space.lg) {
                        teller("Geweest", ContactInzet.urenTekst(minuten: inzet.geweestMinuten))
                        teller("Nog gepland", ContactInzet.urenTekst(minuten: inzet.geplandMinuten))
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(inzet.regels) { regel in
                            inzetRij(regel)
                            if regel.id != inzet.regels.last?.id {
                                Divider().overlay(BovexaTheme.Colors.edge)
                            }
                        }
                    }
                }
            }
        }
    }

    private func teller(_ label: String, _ waarde: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(waarde)
                .font(BovexaTheme.TypeStyle.headline)
                .foregroundStyle(BovexaTheme.Colors.ink)
            Text(label)
                .font(BovexaTheme.TypeStyle.caption)
                .foregroundStyle(BovexaTheme.Colors.muted)
        }
    }

    private func inzetRij(_ regel: ContactInzet.Regel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BovexaTheme.Space.sm) {
            VStack(alignment: .leading, spacing: 1) {
                Text(EventHelpers.longDay(regel.start))
                    .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                Text(tijdTekst(regel))
                    .font(BovexaTheme.TypeStyle.caption)
                    .foregroundStyle(BovexaTheme.Colors.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: BovexaTheme.Space.sm)
            // Een afspraak zonder eindtijd levert nul minuten op; dan liever niets
            // dan een misleidende "0 uur".
            if regel.minuten > 0 {
                Text(ContactInzet.urenTekst(minuten: regel.minuten))
                    .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                    .foregroundStyle(regel.geweest ? BovexaTheme.Colors.inkSoft : BovexaTheme.Colors.accent)
            }
        }
        .padding(.vertical, BovexaTheme.Space.xs)
    }

    private func tijdTekst(_ regel: ContactInzet.Regel) -> String {
        if regel.heleDag { return "Hele dag · \(regel.titel)" }
        let van = EventHelpers.fmtTime(regel.start)
        guard let einde = regel.einde else { return "\(van) · \(regel.titel)" }
        return "\(van) - \(EventHelpers.fmtTime(einde)) · \(regel.titel)"
    }

    private func field(label: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
            Text(label)
                .font(BovexaTheme.TypeStyle.caption.weight(.semibold))
                .foregroundStyle(BovexaTheme.Colors.muted)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .autocorrectionDisabled(keyboard != .default)
                .font(BovexaTheme.TypeStyle.body)
        }
    }

    private func save() async {
        saving = true
        let success = await onSave(naam, telefoon, notitie)
        saving = false
        if success { dismiss() }
    }
}

#Preview {
    PersoonFormView(mode: .add) { _, _, _ in true }
}

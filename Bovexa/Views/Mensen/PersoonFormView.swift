import SwiftUI

/// Formulier voor een privécontact: aanmaken of wijzigen/verwijderen (m8). Alleen
/// naam, telefoon en notitie — geen account, geen koppeling (valkuil B).
struct PersoonFormView: View {
    enum Mode {
        case add
        case edit(AgendaContact)
    }

    let mode: Mode
    let onSave: (String, String, String) async -> Bool
    var onDelete: (() async -> Void)?
    /// De foutmelding stond als `.alert` op MensenView, ónder deze sheet — SwiftUI
    /// presenteert die dan niet: de spinner flitste en er gebeurde niets. De tekst
    /// hoort hier, bij de knop die faalde.
    var errorText: String?

    @Environment(\.dismiss) private var dismiss
    @State private var naam: String
    @State private var telefoon: String
    @State private var notitie: String
    @State private var saving = false
    @State private var showDeleteConfirm = false

    init(
        mode: Mode,
        onSave: @escaping (String, String, String) async -> Bool,
        onDelete: (() async -> Void)? = nil,
        errorText: String? = nil
    ) {
        self.mode = mode
        self.onSave = onSave
        self.onDelete = onDelete
        self.errorText = errorText
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

                        if case .edit = mode {
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

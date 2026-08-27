import SwiftUI

/// Herinnering-chips: Geen / 15 min vooraf / 1 uur vooraf / 1 dag vooraf, plus
/// "Anders…" voor een zelfgekozen tijd. Zonder die laatste zat je vast aan de vier
/// vaste stappen; een eigen keuze krijgt een eigen chip vóór "Anders…".
///
/// Meerdere tijden tegelijk mag: "15 min vooraf" én "1 uur vooraf" staan gewoon
/// samen aan. Elke knop is een schakelaar — nog een keer tikken zet hem weer uit.
/// "Geen" is de knop die alles uitzet.
struct ReminderChipsView: View {
    @Binding var minuten: [Int]
    var disabled: Bool = false

    @State private var toonAnders = false
    @State private var andersTekst = ""

    /// De gekozen tijden die niet bij een vaste knop horen: die krijgen een eigen
    /// chip, anders zou de keuze nergens meer te zien zijn.
    private var eigenTijden: [Int] {
        minuten.filter { tijd in !ReminderOption.all.contains { $0.minutes == tijd } }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BovexaTheme.Space.xs) {
                chip("Geen", active: minuten.isEmpty) {
                    withAnimation(.snappy) { minuten = [] }
                }
                ForEach(ReminderOption.all.filter { $0.minutes > 0 }) { option in
                    chip(option.label, active: minuten.contains(option.minutes)) {
                        withAnimation(.snappy) { wissel(option.minutes) }
                    }
                }
                ForEach(eigenTijden, id: \.self) { tijd in
                    chip(ReminderOption.vrijLabel(minutes: tijd), active: true) {
                        withAnimation(.snappy) { wissel(tijd) }
                    }
                }
                chip("Anders…", active: false) {
                    andersTekst = ""
                    toonAnders = true
                }
            }
        }
        .alert("Hoeveel minuten vooraf?", isPresented: $toonAnders) {
            TextField("Bijvoorbeeld 30", text: $andersTekst)
                .keyboardType(.numberPad)
            Button("Annuleren", role: .cancel) { andersTekst = "" }
            Button("Toevoegen") { voegEigenTijdToe() }
        } message: {
            Text("Bijvoorbeeld 30 voor een half uur, 120 voor twee uur.")
        }
    }

    /// Stond hij aan, dan gaat hij eraf; stond hij eruit, dan komt hij erbij.
    private func wissel(_ tijd: Int) {
        if let index = minuten.firstIndex(of: tijd) {
            minuten.remove(at: index)
        } else {
            minuten.append(tijd)
        }
        minuten = HerinneringStore.opschonen(minuten)
    }

    /// Onzin (leeg, nul, letters) laat de keuze staan zoals hij was; tien dagen is
    /// de bovengrens.
    private func voegEigenTijdToe() {
        guard let waarde = Int(andersTekst.trimmingCharacters(in: .whitespaces)), waarde > 0 else {
            andersTekst = ""
            return
        }
        withAnimation(.snappy) { minuten = HerinneringStore.opschonen(minuten + [min(waarde, 14400)]) }
        andersTekst = ""
        Haptics.success()
    }

    private func chip(_ label: String, active: Bool, onTap: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            onTap()
        } label: {
            Text(label)
                .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                .foregroundStyle(active ? BovexaTheme.Colors.white : BovexaTheme.Colors.muted)
                .padding(.horizontal, BovexaTheme.Space.md)
                .frame(minHeight: 44)
                .background(active ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.glass)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(active ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.edge, lineWidth: 1)
                )
        }
        .disabled(disabled)
    }
}

#Preview {
    ZStack {
        AppBackground()
        ReminderChipsView(minuten: .constant([15, 60]))
            .padding()
    }
}

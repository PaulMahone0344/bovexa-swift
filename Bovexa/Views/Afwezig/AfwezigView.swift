import SwiftUI

/// Beschikbaarheidsscherm: maandraster met periode-selectie en twee meldingen —
/// "Beschikbaarheid doorgeven" (ik kán werken) en "Afwezigheid doorgeven" (ik ben
/// weg, met de reden ernaast). Wat er is doorgegeven staat eronder in een lijst.
/// Geport uit afwezig.tsx (valkuil I). Hergebruikt MonthGridBuilder (dezelfde
/// maandag-eerst-grid als de Agenda-maandweergave) i.p.v. een eigen grid.
struct AfwezigView: View {
    @StateObject private var viewModel: AfwezigViewModel
    @Environment(\.dismiss) private var dismiss
    private let hasOrg: Bool
    /// Welke van de twee knoppen de spinner krijgt. `viewModel.saving` weet dat
    /// zelf niet, dus zonder dit zouden ze allebei tegelijk draaien.
    @State private var bezigeSoort: MeldSoort = .beschikbaar
    /// De lijst onder de knoppen leest hieruit. Het viewmodel houdt dezelfde store
    /// vast, maar geeft wijzigingen niet door — vandaar hier apart.
    @ObservedObject private var store = BeschikbaarheidStore.shared
    /// Keuzemenu met de reden; verschijnt pas als je op de rode knop tikt.
    @State private var toonRedenKeuze = false
    /// "Anders" vraagt eerst om een toelichting voordat er iets wordt opgeslagen.
    @State private var toonAndersInvoer = false
    /// Laatste stap: pas na "Doorgeven" gaat het naar de server.
    @State private var toonBevestiging = false
    /// De melding die de gebruiker wil intrekken; nil zolang er niets gekozen is.
    @State private var intrekken: Beschikbaarheidsmelding?

    /// Twee letters, gelijk aan de maandweergave in de Agenda. Één letter gaf
    /// "M D W D V Z Z": twee keer D en twee keer Z, dus niet te zien of je op
    /// dinsdag of donderdag tikt. Deze kalender is net zo breed als die in de
    /// Agenda, dus er is ruimte voor.
    private static let weekLabels = ["Ma", "Di", "Wo", "Do", "Vr", "Za", "Zo"]

    init(userId: String, org: String?, token: String) {
        _viewModel = StateObject(wrappedValue: AfwezigViewModel(userId: userId, org: org, token: token))
        hasOrg = org != nil
    }

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    GlassCard {
                        VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                            periodSection
                            herhaalSectie
                            tijdSectie
                            opmerkingSectie
                            if viewModel.tooLong {
                                Text("Maximaal \(AfwezigRange.maxDays) dagen per keer.")
                                    .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                                    .foregroundStyle(BovexaTheme.Colors.danger)
                            }
                            afwezigKnop
                            doorgegevenSectie
                        }
                    }
                    .padding(BovexaTheme.Space.xl)

                    Text(viewModel.effectiveHeleDag
                         ? "Je team ziet dit als hele-dag blok\(hasOrg ? " in de gedeelde agenda" : "")."
                         : "Je team ziet dit als tijdsblok\(hasOrg ? " in de gedeelde agenda" : "").")
                        .font(BovexaTheme.TypeStyle.caption)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BovexaTheme.Space.xl)
                        // Sheet, dus geen tabbalk eronder: tabBarClearance (104) liet hier
                    // een gat achter (5c).
                    .padding(.bottom, BovexaTheme.Space.xl)
                }
                // Naar beneden vegen sluit het toetsenbord; anders bleef het staan
                // over de knoppen heen.
                .scrollDismissesKeyboard(.interactively)
            }
            // Wie de beheerder is bepaalt naar wie het blok gaat; zonder dit zou
            // het privé blijven en zag niemand het.
            .task { await viewModel.laadBeheerders() }
            .navigationTitle("Beschikbaarheid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetCloseButton { dismiss() }
            }
            // Blijft open na "Oké": de doorgegeven periode verschijnt onderaan in
            // de lijst, en dat mis je als het scherm meteen dichtklapt.
            .alert("Gelukt", isPresented: Binding(get: { viewModel.savedAlertMessage != nil }, set: { if !$0 { viewModel.savedAlertMessage = nil } })) {
                Button("Oké") {}
            } message: {
                Text(viewModel.savedAlertMessage ?? "")
            }
            .confirmationDialog("Waarom ben je afwezig?", isPresented: $toonRedenKeuze, titleVisibility: .visible) {
                ForEach(AfwezigReason.allCases) { reason in
                    Button(reason.label) {
                        viewModel.reason = reason
                        if reason == .anders {
                            toonAndersInvoer = true
                        } else {
                            toonBevestiging = true
                        }
                    }
                }
                Button("Annuleren", role: .cancel) {}
            }
            // Losse invoer, want een tekstveld kan niet in een confirmationDialog.
            .alert("Waarvoor ben je weg?", isPresented: $toonAndersInvoer) {
                TextField("Bijvoorbeeld: tandarts", text: $viewModel.andersToelichting)
                Button("Verder") { toonBevestiging = true }
                Button("Annuleren", role: .cancel) {}
            }
            // Laatste controle vóór het naar het team gaat: verkeerde dag of
            // verkeerde reden is achteraf gedoe om weer weg te halen.
            .confirmationDialog(bevestigingsTekst, isPresented: $toonBevestiging, titleVisibility: .visible) {
                Button(bezigeSoort == .beschikbaar ? "Beschikbaarheid doorgeven" : "Afwezigheid doorgeven") {
                    Task { await viewModel.save(soort: bezigeSoort) }
                }
                Button("Terug", role: .cancel) {}
            }
            .confirmationDialog(
                "Deze melding intrekken?",
                isPresented: Binding(get: { intrekken != nil }, set: { if !$0 { intrekken = nil } }),
                titleVisibility: .visible
            ) {
                Button("Verwijderen", role: .destructive) {
                    if let melding = intrekken {
                        Task { await viewModel.trekIn(melding) }
                    }
                    intrekken = nil
                }
                Button("Laten staan", role: .cancel) { intrekken = nil }
            } message: {
                Text("De dagen verdwijnen ook uit de agenda van je beheerder.")
            }
            .alert("Mislukt", isPresented: $viewModel.saveFailedAlert) {
                Button("Oké", role: .cancel) {}
            } message: {
                Text("Kon je beschikbaarheid niet opslaan. Probeer het nog een keer.")
            }
        }
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            Text("PERIODE")
                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.accent)
                .tracking(0.3)

            Text(periodHint)
                .font(BovexaTheme.TypeStyle.footnote)
                .foregroundStyle(BovexaTheme.Colors.muted)

            monthNav
            weekHeader
            monthGrid
        }
    }

    private var periodHint: String {
        let aantal = viewModel.range.count
        guard let from = viewModel.from else {
            return "Tik de dagen aan. Lang drukken kiest de hele week."
        }
        if aantal > 1 {
            return "\(aantal) dagen gekozen — tik een dag nog eens om hem weg te halen"
        }
        return "\(EventHelpers.longDay(from)) — tik meer dagen aan als je er meer wilt"
    }

    private var monthNav: some View {
        HStack {
            Button {
                viewModel.shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left").frame(minWidth: 44)
            }
            .buttonStyle(.glassSecondaryBrand)
            .accessibilityLabel("Vorige maand")

            Spacer()

            Text(monthTitle)
                .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.ink)

            Spacer()

            Button {
                viewModel.shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right").frame(minWidth: 44)
            }
            .buttonStyle(.glassSecondaryBrand)
            .accessibilityLabel("Volgende maand")
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: viewModel.cursorMonth).capitalized
    }

    private var weekHeader: some View {
        HStack {
            ForEach(Array(Self.weekLabels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                    .foregroundStyle(BovexaTheme.Colors.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let cells = MonthGridBuilder.cells(for: viewModel.cursorMonth, today: today)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(cells) { cell in
                if cell.isCurrentMonth {
                    dayCell(cell)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private func dayCell(_ cell: MonthDayCell) -> some View {
        let past = cell.date < today
        let active = viewModel.isInRange(cell.date)
        // Blauw wat je als beschikbaar hebt doorgegeven, rood wat je als
        // afwezigheid hebt doorgegeven. Zo zie je in één blik wat er al staat.
        let doorgegeven = viewModel.doorgegevenSoort(op: cell.date)
        return Button {
            Haptics.selection()
            viewModel.pickDay(cell.date)
        } label: {
            Text("\(Calendar.current.component(.day, from: cell.date))")
                .font(BovexaTheme.TypeStyle.subheadline.weight(active || doorgegeven != nil ? .bold : .medium))
                .foregroundStyle(past ? BovexaTheme.Colors.muted.opacity(0.5) : dagKleur(doorgegeven))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(dagVulling(doorgegeven: doorgegeven, active: active))
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous)
                        .strokeBorder(active ? BovexaTheme.Colors.ink.opacity(0.45) : Color.clear, lineWidth: 2)
                )
        }
        .disabled(past)
        .contextMenu {
            Button("Hele week kiezen") { viewModel.kiesHeleWeek(van: cell.date) }
            if !viewModel.range.isEmpty {
                Button("Selectie wissen", role: .destructive) { viewModel.wisSelectie() }
            }
        }
    }

    /// Samenvatting in de bevestiging: wát je doorgeeft, op welke dagen en welke
    /// tijden.
    private var bevestigingsTekst: String {
        let aantal = viewModel.range.count
        let wat = bezigeSoort == .beschikbaar ? "Beschikbaar" : viewModel.reason.label
        let dagen = aantal == 1 ? "1 dag" : "\(aantal) dagen"
        let tijd = viewModel.effectiveHeleDag
            ? "hele dag"
            : "\(EventHelpers.fmtTime(viewModel.startTime)) – \(EventHelpers.fmtTime(viewModel.endTime))"
        return "\(wat) · \(dagen) · \(tijd)"
    }

    private func dagKleur(_ doorgegeven: MeldSoort?) -> Color {
        switch doorgegeven {
        case .beschikbaar: return BovexaTheme.Colors.accent
        case .afwezig: return BovexaTheme.Colors.danger
        case nil: return BovexaTheme.Colors.ink
        }
    }

    private func dagVulling(doorgegeven: MeldSoort?, active: Bool) -> Color {
        switch doorgegeven {
        case .beschikbaar: return BovexaTheme.Colors.accent.opacity(0.22)
        case .afwezig: return BovexaTheme.Colors.danger.opacity(0.22)
        case nil: return active ? BovexaTheme.categoryColor(for: .afwezig).opacity(0.35) : Color.clear
        }
    }

    /// Herhalen: elke dag, of alleen op de weekdagen die je aantikt, tot een
    /// einddatum. Uit staat er niets extra's in beeld.
    @ViewBuilder
    private var herhaalSectie: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            Toggle(isOn: $viewModel.herhalen.animation(.snappy)) {
                Text("Herhalen")
                    .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                    .foregroundStyle(BovexaTheme.Colors.ink)
            }
            .tint(BovexaTheme.categoryColor(for: .afwezig))

            if viewModel.herhalen {
                HStack(spacing: BovexaTheme.Space.sm) {
                    ForEach(AfwezigViewModel.HerhaalModus.allCases) { modus in
                        modusKnop(modus)
                    }
                }

                if viewModel.herhaalModus == .geselecteerdeDagen {
                    HStack(spacing: 4) {
                        ForEach(Array(Self.weekdagNummers.enumerated()), id: \.offset) { index, nummer in
                            weekdagKnop(label: Self.weekLabels[index], nummer: nummer)
                        }
                    }
                }

                HStack {
                    Text("Einddatum")
                        .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                    Spacer()
                    DatePicker(
                        "Einddatum",
                        selection: Binding(
                            get: { viewModel.herhaalEinddatum ?? standaardEinddatum },
                            set: { viewModel.herhaalEinddatum = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }

                Text("\(viewModel.doorTeGevenDagen.count) dag\(viewModel.doorTeGevenDagen.count == 1 ? "" : "en") in deze reeks")
                    .font(BovexaTheme.TypeStyle.caption)
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }
        }
    }

    /// Vier weken vooruit: zonder einddatum loopt de reeks tot daar, en dan wijst
    /// de kiezer ook meteen die dag aan.
    private var standaardEinddatum: Date {
        let start = viewModel.range.first ?? today
        return Calendar.current.date(byAdding: .day, value: 27, to: start) ?? start
    }

    /// Calendar telt zondag als 1; deze rij begint op maandag, net als de kalender.
    private static let weekdagNummers = [2, 3, 4, 5, 6, 7, 1]

    private func modusKnop(_ modus: AfwezigViewModel.HerhaalModus) -> some View {
        let actief = viewModel.herhaalModus == modus
        return Button {
            Haptics.selection()
            viewModel.herhaalModus = modus
        } label: {
            Text(modus.label)
                .font(BovexaTheme.TypeStyle.footnote.weight(.bold))
                .foregroundStyle(actief ? BovexaTheme.Colors.white : BovexaTheme.Colors.muted)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(actief ? BovexaTheme.categoryColor(for: .afwezig) : BovexaTheme.Colors.glass)
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous)
                        .strokeBorder(actief ? Color.clear : BovexaTheme.Colors.edge, lineWidth: 1)
                )
        }
    }

    private func weekdagKnop(label: String, nummer: Int) -> some View {
        let actief = viewModel.herhaalWeekdagen.contains(nummer)
        return Button {
            Haptics.selection()
            if actief {
                viewModel.herhaalWeekdagen.remove(nummer)
            } else {
                viewModel.herhaalWeekdagen.insert(nummer)
            }
        } label: {
            Text(label)
                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                .foregroundStyle(actief ? BovexaTheme.Colors.white : BovexaTheme.Colors.muted)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(actief ? BovexaTheme.categoryColor(for: .afwezig) : BovexaTheme.Colors.glass)
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous)
                        .strokeBorder(actief ? Color.clear : BovexaTheme.Colors.edge, lineWidth: 1)
                )
        }
    }

    /// Vrij veld voor een woordje uitleg; de beheerder leest het bij de aanvraag.
    private var opmerkingSectie: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            Text("OPMERKING")
                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.accent)
                .tracking(0.3)

            TextField("Bijvoorbeeld: tandarts", text: $viewModel.opmerking, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .padding(BovexaTheme.Space.sm)
                .background(BovexaTheme.Colors.glassSoft)
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous)
                        .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
                )
        }
    }

    private var tijdSectie: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            Text("SELECTEER TIJD")
                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.accent)
                .tracking(0.3)

            Toggle(isOn: $viewModel.heleDag) {
                Text("Hele dag")
                    .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                    .foregroundStyle(BovexaTheme.Colors.ink)
            }
            .tint(BovexaTheme.categoryColor(for: .afwezig))

            if !viewModel.heleDag {
                HStack(spacing: BovexaTheme.Space.sm) {
                    DatePicker("Van", selection: $viewModel.startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Text("t/m")
                        .font(BovexaTheme.TypeStyle.footnote)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                    DatePicker("Tot", selection: $viewModel.endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                if viewModel.endTime <= viewModel.startTime {
                    Text("Eindtijd moet na de begintijd liggen.")
                        .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                        .foregroundStyle(BovexaTheme.Colors.danger)
                }
            }
        }
    }

    /// "Ik ben weg." De reden vraagt de app pas ná het tikken, in een keuzemenu:
    /// een losse redenknop ernaast liet je iets instellen waarvan niet duidelijk
    /// was waar het bij hoorde.
    private var afwezigKnop: some View {
        Button {
            bezigeSoort = .afwezig
            toonRedenKeuze = true
        } label: {
            if viewModel.saving && bezigeSoort == .afwezig {
                ProgressView().tint(BovexaTheme.Colors.danger).frame(maxWidth: .infinity)
            } else {
                Text("Afwezigheid doorgeven").frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.glassSecondaryDanger)
        .disabled(viewModel.saving || viewModel.from == nil || viewModel.tooLong)
    }

    /// Wat er al doorgegeven is, onder de knoppen. Vandaag en later; wat voorbij is
    /// hoeft niemand meer te zien.
    @ViewBuilder
    private var doorgegevenSectie: some View {
        let meldingen = store.komende()
        if !meldingen.isEmpty {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                Divider().overlay(BovexaTheme.Colors.edge)

                Text("DOORGEGEVEN")
                    .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                    .foregroundStyle(BovexaTheme.Colors.accent)
                    .tracking(0.3)

                ForEach(meldingen) { melding in
                    meldingRij(melding)
                }
            }
        }
    }

    private func meldingRij(_ melding: Beschikbaarheidsmelding) -> some View {
        HStack(alignment: .top, spacing: BovexaTheme.Space.sm) {
            Circle()
                .fill(melding.soort == .beschikbaar ? BovexaTheme.Colors.accent : BovexaTheme.Colors.danger)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(AfwezigMeldingTekst.dagen(melding))
                    .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                Text(AfwezigMeldingTekst.tijden(melding))
                    .font(BovexaTheme.TypeStyle.footnote)
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }

            Spacer(minLength: BovexaTheme.Space.sm)

            Text(melding.soortLabel)
                .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                .foregroundStyle(melding.soort == .beschikbaar ? BovexaTheme.Colors.accent : BovexaTheme.Colors.danger)

            // Intrekken haalt de dagen ook echt van de server af, niet alleen uit
            // dit lijstje.
            Button {
                Haptics.selection()
                intrekken = melding
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(BovexaTheme.Colors.danger)
                    .frame(width: 32, height: 32)
                    .background(BovexaTheme.Colors.glass)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Melding intrekken")
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    AfwezigView(userId: "u1", org: "org1", token: "tok")
}

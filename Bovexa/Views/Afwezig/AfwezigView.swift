import SwiftUI

/// Afwezig-scherm: reden-chips, maandraster met periode-selectie, "Beschikbaarheid
/// doorgeven". Geport uit afwezig.tsx (valkuil I). Hergebruikt MonthGridBuilder
/// (dezelfde maandag-eerst-grid als de Agenda-maandweergave) i.p.v. een eigen grid.
struct AfwezigView: View {
    @StateObject private var viewModel: AfwezigViewModel
    @Environment(\.dismiss) private var dismiss
    private let hasOrg: Bool

    private static let weekLabels = ["M", "D", "W", "D", "V", "Z", "Z"]

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
                            reasonSection
                            periodSection
                            if viewModel.isSingleDaySelection {
                                heleDagSection
                            }
                            if viewModel.tooLong {
                                Text("Maximaal \(AfwezigRange.maxDays) dagen per keer.")
                                    .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                                    .foregroundStyle(BovexaTheme.Colors.danger)
                            }
                            submitButton
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
                        .padding(.bottom, BovexaTheme.Space.tabBarClearance)
                }
            }
            .navigationTitle("Beschikbaarheid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            .alert("Gelukt", isPresented: Binding(get: { viewModel.savedAlertMessage != nil }, set: { if !$0 { viewModel.savedAlertMessage = nil } })) {
                Button("Oké") { dismiss() }
            } message: {
                Text(viewModel.savedAlertMessage ?? "")
            }
            .alert("Mislukt", isPresented: $viewModel.saveFailedAlert) {
                Button("Oké", role: .cancel) {}
            } message: {
                Text("Kon je beschikbaarheid niet opslaan. Probeer het nog een keer.")
            }
        }
    }

    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            Text("REDEN")
                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.accent)
                .tracking(0.3)

            HStack(spacing: BovexaTheme.Space.sm) {
                ForEach(AfwezigReason.allCases) { reason in
                    reasonChip(reason)
                }
            }

            if viewModel.reason == .anders {
                TextField("Toelichting (verplicht)", text: $viewModel.andersToelichting)
                    .padding(.horizontal, BovexaTheme.Space.md)
                    .frame(minHeight: 44)
                    .background(BovexaTheme.Colors.glass)
                    .overlay(
                        RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                            .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
            }
        }
    }

    private func reasonChip(_ reason: AfwezigReason) -> some View {
        let active = viewModel.reason == reason
        return Button {
            Haptics.selection()
            viewModel.reason = reason
        } label: {
            Text(reason.label)
                .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                .foregroundStyle(active ? BovexaTheme.Colors.white : BovexaTheme.Colors.muted)
                .padding(.horizontal, BovexaTheme.Space.md)
                .frame(minHeight: 38)
                .background(active ? BovexaTheme.categoryColor(for: .afwezig) : BovexaTheme.Colors.glass)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(active ? BovexaTheme.categoryColor(for: .afwezig) : BovexaTheme.Colors.edge, lineWidth: 1))
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
        guard let from = viewModel.from else { return "Tik een dag in de kalender." }
        if let to = viewModel.to, !Calendar.current.isDate(from, inSameDayAs: to) {
            return "\(viewModel.range.count) dag\(viewModel.range.count == 1 ? "" : "en") geselecteerd"
        }
        return "\(EventHelpers.longDay(from)) — tik nog een dag voor een periode"
    }

    private var monthNav: some View {
        HStack {
            Button {
                viewModel.shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.glassSecondaryBrand)

            Spacer()

            Text(monthTitle)
                .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.ink)

            Spacer()

            Button {
                viewModel.shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.glassSecondaryBrand)
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
        return Button {
            Haptics.selection()
            viewModel.pickDay(cell.date)
        } label: {
            Text("\(Calendar.current.component(.day, from: cell.date))")
                .font(BovexaTheme.TypeStyle.subheadline.weight(active ? .bold : .medium))
                .foregroundStyle(past ? BovexaTheme.Colors.muted.opacity(0.5) : (active ? BovexaTheme.Colors.ink : BovexaTheme.Colors.ink))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(active ? BovexaTheme.categoryColor(for: .afwezig).opacity(0.35) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous))
        }
        .disabled(past)
    }

    private var heleDagSection: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
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

    private var submitButton: some View {
        Button {
            Task { await viewModel.save() }
        } label: {
            if viewModel.saving {
                ProgressView().tint(BovexaTheme.Colors.white)
            } else {
                Text("Beschikbaarheid doorgeven")
            }
        }
        .buttonStyle(.glassProminentBrand)
        .frame(maxWidth: .infinity)
        .disabled(!viewModel.canSave)
    }
}

#Preview {
    AfwezigView(userId: "u1", org: "org1", token: "tok")
}

import SwiftUI

/// Het overzicht dat opengaat als je in Mensen op een collega tikt: zijn gegevens,
/// hoeveel dagen hij heeft gewerkt en nog staat ingepland, en wanneer hij afwezig
/// was en waarom.
///
/// Alleen-lezen. Rol, rechten en verwijderen horen bij Bedrijf > Teambeheer; dit
/// scherm is er om te zien hoe iemand ervoor staat, niet om hem te beheren.
struct MedewerkerDetailView: View {
    @StateObject private var viewModel: MedewerkerDetailViewModel
    @Environment(\.dismiss) private var dismiss

    private let member: CompanyMember
    private let userId: String
    private let orgId: String?
    private let token: String

    init(member: CompanyMember, userId: String, orgId: String?, token: String) {
        _viewModel = StateObject(wrappedValue: MedewerkerDetailViewModel())
        self.member = member
        self.userId = userId
        self.orgId = orgId
        self.token = token
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                        kop
                        gegevens
                        if viewModel.loading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, BovexaTheme.Space.xl)
                        } else if viewModel.loadFailed {
                            EmptyStateView(
                                systemImage: "wifi.slash",
                                text: "De agenda kon niet worden geladen.",
                                surface: .background
                            )
                        } else {
                            inzet
                            afwezigheid
                        }
                    }
                    .padding(BovexaTheme.Space.xl)
                    .padding(.bottom, BovexaTheme.Space.tabBarClearance)
                }
            }
            .navigationTitle(voornaam)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                SheetCloseButton { dismiss() }
            }
        }
        .task {
            await viewModel.load(medewerkerId: member.userId, userId: userId, orgId: orgId, token: token)
        }
    }

    private var voornaam: String {
        member.displayName.split(separator: " ").first.map(String.init) ?? member.displayName
    }

    private var achternaam: String {
        let delen = member.displayName.split(separator: " ").dropFirst()
        return delen.isEmpty ? "" : delen.joined(separator: " ")
    }

    private var kop: some View {
        HStack(spacing: BovexaTheme.Space.md) {
            initialBadge(member.displayName, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(BovexaTheme.TypeStyle.title3.weight(.bold))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                Text(rolLabel)
                    .font(BovexaTheme.TypeStyle.caption)
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }
            Spacer()
        }
    }

    private var rolLabel: String {
        if member.isOwner { return "Eigenaar" }
        switch member.role {
        case .admin: return "Beheerder"
        case .manager: return "Manager"
        case .member: return "Medewerker"
        }
    }

    // MARK: - Gegevens

    private var gegevens: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            kopje("GEGEVENS")
            GlassCard(padding: BovexaTheme.Space.xs) {
                VStack(alignment: .leading, spacing: 0) {
                    regel("Voornaam", voornaam, first: true)
                    if !achternaam.isEmpty {
                        regel("Achternaam", achternaam, first: false)
                    }
                    regel("E-mail", member.email.isEmpty ? "Niet bekend" : member.email, first: false)
                    regel("Rol", rolLabel, first: false)
                }
            }
        }
    }

    // MARK: - Ingepland en gewerkt

    private var inzet: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            kopje("DAGEN")
            HStack(spacing: BovexaTheme.Space.sm) {
                telKaart(
                    getal: viewModel.gewerkteDagen,
                    label: viewModel.gewerkteDagen == 1 ? "dag gewerkt" : "dagen gewerkt",
                    onder: MedewerkerInzet.urenTekst(minuten: viewModel.gewerktMinuten)
                )
                telKaart(
                    getal: viewModel.geplandeDagen,
                    label: viewModel.geplandeDagen == 1 ? "dag gepland" : "dagen gepland",
                    onder: MedewerkerInzet.urenTekst(minuten: viewModel.geplandMinuten)
                )
            }

            if viewModel.dagen.isEmpty {
                EmptyStateView(
                    systemImage: "calendar",
                    text: "Nog niets ingepland voor \(voornaam).",
                    surface: .background
                )
            } else {
                GlassCard(padding: BovexaTheme.Space.xs) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Een lange lijst is hier niet het doel: je wilt zien wat er
                        // laatst was en wat eraan komt, niet een jaar terugscrollen.
                        ForEach(Array(viewModel.dagen.prefix(12).enumerated()), id: \.element.id) { index, dag in
                            dagRegel(dag, first: index == 0)
                        }
                    }
                }
                if viewModel.dagen.count > 12 {
                    Text("En nog \(viewModel.dagen.count - 12) eerdere afspraken.")
                        .font(BovexaTheme.TypeStyle.caption)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                }
            }
        }
    }

    private func dagRegel(_ dag: MedewerkerInzet.Dag, first: Bool) -> some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dag.titel.isEmpty ? "Afspraak" : dag.titel)
                    .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                Text(datumTekst(start: dag.start, einde: dag.einde, heleDag: dag.heleDag))
                    .font(BovexaTheme.TypeStyle.caption)
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }
            Spacer()
            Text(dag.geweest ? "Geweest" : "Gepland")
                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                .foregroundStyle(dag.geweest ? BovexaTheme.Colors.muted : BovexaTheme.Colors.accent)
        }
        .padding(.horizontal, BovexaTheme.Space.sm)
        .padding(.vertical, BovexaTheme.Space.sm)
        .overlay(alignment: .top) {
            if !first {
                Rectangle().fill(BovexaTheme.Colors.edgeSoft).frame(height: 1)
            }
        }
    }

    // MARK: - Afwezigheid

    private var afwezigheid: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            kopje("AFWEZIG")

            if viewModel.afwezig.isEmpty {
                EmptyStateView(
                    systemImage: "checkmark.circle",
                    text: "\(voornaam) heeft zich nooit afgemeld.",
                    surface: .background
                )
            } else {
                HStack(spacing: BovexaTheme.Space.sm) {
                    telKaart(
                        getal: viewModel.afwezig.count,
                        label: viewModel.afwezig.count == 1 ? "keer afgemeld" : "keer afgemeld",
                        onder: nil
                    )
                    telKaart(
                        getal: viewModel.afwezigeDagen,
                        label: viewModel.afwezigeDagen == 1 ? "dag weg" : "dagen weg",
                        onder: nil
                    )
                }

                if viewModel.redenen.count > 1 {
                    Text(viewModel.redenen.map { "\($0.reden) \($0.aantal)×" }.joined(separator: " · "))
                        .font(BovexaTheme.TypeStyle.caption)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                }

                GlassCard(padding: BovexaTheme.Space.xs) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(viewModel.afwezig.prefix(12).enumerated()), id: \.element.id) { index, blok in
                            afwezigRegel(blok, first: index == 0)
                        }
                    }
                }
            }
        }
    }

    private func afwezigRegel(_ blok: MedewerkerInzet.Afwezig, first: Bool) -> some View {
        HStack(alignment: .top, spacing: BovexaTheme.Space.sm) {
            Image(systemName: "beach.umbrella.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BovexaTheme.Colors.categoryAmber)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(blok.reden)
                    .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                Text(datumTekst(start: blok.start, einde: blok.einde, heleDag: blok.heleDag))
                    .font(BovexaTheme.TypeStyle.caption)
                    .foregroundStyle(BovexaTheme.Colors.muted)
                if let toelichting = blok.toelichting {
                    Text(toelichting)
                        .font(BovexaTheme.TypeStyle.caption)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                }
            }
            Spacer()
        }
        .padding(.horizontal, BovexaTheme.Space.sm)
        .padding(.vertical, BovexaTheme.Space.sm)
        .overlay(alignment: .top) {
            if !first {
                Rectangle().fill(BovexaTheme.Colors.edgeSoft).frame(height: 1)
            }
        }
    }

    // MARK: - Bouwstenen

    private func initialBadge(_ naam: String, size: CGFloat) -> some View {
        let kleur = BovexaTheme.Colors.accent
        return Circle()
            .fill(kleur.opacity(0.18))
            .frame(width: size, height: size)
            .overlay(Circle().stroke(kleur, lineWidth: 2))
            .overlay {
                Text(naam.prefix(1).uppercased())
                    .font(.system(size: size * 0.42, design: .rounded).weight(.bold))
                    .foregroundStyle(kleur)
            }
    }

    private func kopje(_ tekst: String) -> some View {
        Text(tekst)
            .font(BovexaTheme.TypeStyle.caption.weight(.bold))
            .foregroundStyle(BovexaTheme.Colors.accent)
    }

    private func regel(_ label: String, _ waarde: String, first: Bool) -> some View {
        HStack {
            Text(label)
                .font(BovexaTheme.TypeStyle.caption)
                .foregroundStyle(BovexaTheme.Colors.muted)
            Spacer()
            Text(waarde)
                .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                .foregroundStyle(BovexaTheme.Colors.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, BovexaTheme.Space.sm)
        .padding(.vertical, BovexaTheme.Space.sm)
        .overlay(alignment: .top) {
            if !first {
                Rectangle().fill(BovexaTheme.Colors.edgeSoft).frame(height: 1)
            }
        }
    }

    private func telKaart(getal: Int, label: String, onder: String?) -> some View {
        GlassCard(padding: BovexaTheme.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(getal)")
                    .font(BovexaTheme.TypeStyle.title2.weight(.bold))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                Text(label)
                    .font(BovexaTheme.TypeStyle.caption)
                    .foregroundStyle(BovexaTheme.Colors.muted)
                if let onder {
                    Text(onder)
                        .font(BovexaTheme.TypeStyle.caption.weight(.semibold))
                        .foregroundStyle(BovexaTheme.Colors.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// "wo 26 aug · 09:00 – 12:00" of, bij een blok van meer dagen, "26 aug – 30 aug".
    private func datumTekst(start: Date, einde: Date?, heleDag: Bool) -> String {
        let kalender = Calendar.current
        let dagFormatter = DateFormatter()
        dagFormatter.locale = Locale(identifier: "nl_NL")
        dagFormatter.dateFormat = "EEE d MMM"

        let tijdFormatter = DateFormatter()
        tijdFormatter.locale = Locale(identifier: "nl_NL")
        tijdFormatter.dateFormat = "HH:mm"

        guard let einde else { return dagFormatter.string(from: start) }

        if !kalender.isDate(start, inSameDayAs: einde) {
            return "\(dagFormatter.string(from: start)) – \(dagFormatter.string(from: einde))"
        }
        if heleDag {
            return "\(dagFormatter.string(from: start)) · hele dag"
        }
        return "\(dagFormatter.string(from: start)) · \(tijdFormatter.string(from: start)) – \(tijdFormatter.string(from: einde))"
    }
}

import SwiftUI

/// Kaart onderaan Vandaag: je dagtaken die nog openstaan.
///
/// Onder de tijdlijn stond een half scherm leeg zodra de dag rond was. "Deze week"
/// stond daar eerst, maar dat herhaalde wat de agenda zelf al laat zien. Dit is de
/// enige informatie op Vandaag die níét uit de agenda komt.
///
/// Bewust alleen tonen en doorverwijzen: afvinken gebeurt op Dagtaken, zodat er
/// één plek is waar een taak verandert.
struct OpenTasksCard: View {
    let tasks: [DagtaakRegel]
    let onOpenDagtaken: () -> Void

    /// Meer dan drie wordt een tweede takenlijst; de rest staat als aantal onder
    /// de knop.
    private static let maxShown = 3

    private var shown: [DagtaakRegel] { Array(tasks.prefix(Self.maxShown)) }
    private var remaining: Int { max(0, tasks.count - Self.maxShown) }

    var body: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            SectionHeading(title: "Dagtaken", systemImage: "checkmark.circle.fill")

            GlassCard {
                if tasks.isEmpty {
                    EmptyStateView(systemImage: "checkmark.circle", text: "Geen openstaande dagtaken.")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(shown) { task in
                            row(task)

                            if task.id != shown.last?.id {
                                Divider()
                                    .overlay(BovexaTheme.Colors.edgeSoft)
                                    .padding(.leading, 30)
                            }
                        }

                        Button {
                            Haptics.selection()
                            onOpenDagtaken()
                        } label: {
                            HStack(spacing: BovexaTheme.Space.xs) {
                                Text(remaining > 0 ? "Nog \(remaining) meer · naar Dagtaken" : "Naar Dagtaken")
                                    .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                                    .foregroundStyle(BovexaTheme.Colors.accent)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(BovexaTheme.Colors.accent)
                            }
                            // Raakvlak was ~28pt hoog; minHeight vóór de
                            // contentShape maakt er 44 van (M11 patroon B).
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.top, BovexaTheme.Space.xs)
                            // Zonder dit is alleen de tekst raakbaar: glas telt niet
                            // mee voor hit-testing.
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// De rij begint met een rondje dat als afvinkvakje leest, maar deed niets
    /// (4i). Afvinken blijft bewust op Dagtaken; de tik gaat daarheen.
    private func row(_ task: DagtaakRegel) -> some View {
        Button {
            Haptics.selection()
            onOpenDagtaken()
        } label: {
            rowContent(task)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opent Dagtaken")
    }

    private func rowContent(_ task: DagtaakRegel) -> some View {
        HStack(alignment: .top, spacing: BovexaTheme.Space.sm) {
            Image(systemName: "circle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(BovexaTheme.Colors.blue.opacity(0.55))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: BovexaTheme.Space.xs) {
                    Text(task.title)
                        .font(BovexaTheme.TypeStyle.body.weight(.medium))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                        .lineLimit(1)

                    // Welke lijst de taak uit komt — zonder dit staan een privé-
                    // taak en een bedrijfstaak er identiek onder elkaar.
                    if let bron = task.bron {
                        Text(bron)
                            .font(BovexaTheme.TypeStyle.caption.weight(.semibold))
                            .foregroundStyle(BovexaTheme.Colors.accent)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(BovexaTheme.Colors.glassSoft, in: Capsule())
                    }
                }

                if !task.body.isEmpty {
                    Text(task.body)
                        .font(BovexaTheme.TypeStyle.caption)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, BovexaTheme.Space.sm)
    }
}

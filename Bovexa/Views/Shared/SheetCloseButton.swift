import SwiftUI

/// Sluitknop voor een sheet (M11 plak 6a, besluit Ibrahim 19 aug). Alle sheets in
/// de app sloten met een "chevron.left" op de leading plek: dat leest als
/// "terug" in een navigatiestapel, niet als "sluit dit scherm". Een kruisje
/// rechtsboven is de iOS-norm.
///
/// Gebruik als toolbar-item, en declareer hem als LAATSTE trailing item zodat hij
/// de rechterrand pakt en een bestaande knop (de plus in Meldingen en de planner)
/// naar links schuift in plaats van te verdwijnen.
struct SheetCloseButton: ToolbarContent {
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Haptics.selection()
                action()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .minTapTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sluiten")
        }
    }
}

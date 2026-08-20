import SwiftUI

/// Wrappende rij via het Layout-protocol (iOS 16+) — voor kleine lijsten (toegewezen-
/// chips, categorie-chips) volstaat dit, geen aparte library nodig.
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = Self.clampedSize(of: subview, maxWidth: maxWidth)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = Self.clampedSize(of: subview, maxWidth: bounds.width)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    /// `sizeThatFits(.unspecified)` geeft een Text met `.lineLimit(1)` zijn ideale
    /// breedte, hoe lang de tekst ook is. Een lange labelnaam of klantnaam werd zo
    /// breder dan de kaart en stak er rechts uit — GlassCard clipt niet (M11 5c).
    /// Vandaar: de beschikbare breedte voorstellen én de uitkomst begrenzen.
    private static func clampedSize(of subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        guard maxWidth.isFinite, maxWidth > 0 else {
            return subview.sizeThatFits(.unspecified)
        }
        let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
        return CGSize(width: min(size.width, maxWidth), height: size.height)
    }

    /// Los testbaar: de regelindeling zonder SwiftUI-machinerie eromheen. Geeft per
    /// element de rij-index, zodat een test kan controleren dat een te breed
    /// element wél op zijn eigen regel komt en niet buiten de kaart steekt.
    static func rowIndices(widths: [CGFloat], maxWidth: CGFloat, spacing: CGFloat) -> [Int] {
        var result: [Int] = []
        var x: CGFloat = 0
        var row = 0
        for width in widths {
            let clamped = min(width, maxWidth)
            if x + clamped > maxWidth, x > 0 {
                x = 0
                row += 1
            }
            result.append(row)
            x += clamped + spacing
        }
        return result
    }
}

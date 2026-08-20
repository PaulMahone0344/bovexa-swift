import Testing
import Foundation
@testable import Bovexa

/// M11 plak 5c: chips werden zo breed als hun ideale tekstbreedte, hoe smal de
/// kaart ook was. Een lange labelnaam of klantnaam stak daardoor rechts buiten de
/// GlassCard, die niet clipt.
struct FlowLayoutTests {
    @Test func chipsThatFitStayOnOneRow() {
        let rows = FlowLayout.rowIndices(widths: [80, 80, 80], maxWidth: 300, spacing: 6)
        #expect(rows == [0, 0, 0])
    }

    @Test func aChipThatDoesNotFitMovesToTheNextRow() {
        let rows = FlowLayout.rowIndices(widths: [200, 200], maxWidth: 300, spacing: 6)
        #expect(rows == [0, 1])
    }

    /// De kern van de fix: een element dat breder is dan de kaart wordt begrensd
    /// en krijgt een eigen regel, in plaats van de rij te laten uitsteken.
    @Test func anOversizedChipGetsItsOwnRowInsteadOfOverflowing() {
        let rows = FlowLayout.rowIndices(widths: [80, 900, 80], maxWidth: 300, spacing: 6)
        #expect(rows == [0, 1, 2])
    }

    @Test func anOversizedChipAloneStillLandsOnTheFirstRow() {
        let rows = FlowLayout.rowIndices(widths: [900], maxWidth: 300, spacing: 6)
        #expect(rows == [0])
    }

    @Test func spacingCountsTowardsTheRowWidth() {
        // 2×145 past (290), maar met 20pt tussenruimte niet meer.
        #expect(FlowLayout.rowIndices(widths: [145, 145], maxWidth: 300, spacing: 0) == [0, 0])
        #expect(FlowLayout.rowIndices(widths: [145, 145], maxWidth: 300, spacing: 20) == [0, 1])
    }

    @Test func noChipsGivesNoRows() {
        #expect(FlowLayout.rowIndices(widths: [], maxWidth: 300, spacing: 6).isEmpty)
    }
}

import Testing
import SwiftUI
@testable import Bovexa

/// Afwezigheid is één categorie maar niet één soort (26 juli): vakantie of vrij
/// groen, ziek rood, de rest amber.
struct AbsenceColorTests {
    @Test func vakantieIsGreen() {
        #expect(BovexaTheme.absenceColor(title: "Vakantie") == BovexaTheme.Colors.categoryGreenDeep)
    }

    @Test func vrijIsGreen() {
        #expect(BovexaTheme.absenceColor(title: "Vrij") == BovexaTheme.Colors.categoryGreenDeep)
    }

    @Test func ziekIsRed() {
        #expect(BovexaTheme.absenceColor(title: "Ziek") == BovexaTheme.Colors.categoryRed)
    }

    /// De RN-app en de toelichting bij "Anders" leveren hele zinnen; een exacte
    /// vergelijking liet "Ziek thuis" amber worden.
    @Test func ziekInASentenceIsStillRed() {
        #expect(BovexaTheme.absenceColor(title: "Ziek thuis") == BovexaTheme.Colors.categoryRed)
    }

    @Test func freeTextFallsBackToAmber() {
        #expect(BovexaTheme.absenceColor(title: "Tandarts") == BovexaTheme.Colors.categoryAmber)
    }

    /// Ziek gaat vóór: "ziek gemeld, vakantie ingetrokken" is geen vrije dag.
    @Test func ziekWinsFromVakantie() {
        #expect(BovexaTheme.absenceColor(title: "Ziek, vakantie afgezegd") == BovexaTheme.Colors.categoryRed)
    }
}

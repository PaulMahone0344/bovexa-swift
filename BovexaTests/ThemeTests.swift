import Testing
import SwiftUI
@testable import Bovexa

struct ThemeTests {
    @Test func colorHexParsesSixDigitHexWithHash() {
        let resolved = Color(hex: "#58AEB7").resolve(in: .init())
        #expect(abs(Double(resolved.red) - 0x58.doubleValue255) < 0.01)
        #expect(abs(Double(resolved.green) - 0xAE.doubleValue255) < 0.01)
        #expect(abs(Double(resolved.blue) - 0xB7.doubleValue255) < 0.01)
    }

    @Test func colorHexParsesWithoutHash() {
        let resolved = Color(hex: "2F858F").resolve(in: .init())
        #expect(abs(Double(resolved.red) - 0x2F.doubleValue255) < 0.01)
        #expect(abs(Double(resolved.green) - 0x85.doubleValue255) < 0.01)
        #expect(abs(Double(resolved.blue) - 0x8F.doubleValue255) < 0.01)
    }

    @Test func radiusTokensMatchSpec() {
        #expect(BovexaTheme.Radius.sm == 14)
        #expect(BovexaTheme.Radius.md == 20)
        #expect(BovexaTheme.Radius.lg == 26)
        #expect(BovexaTheme.Radius.pill == 999)
        #expect(BovexaTheme.Radius.phone == 48)
    }

    @Test func spaceTokensMatchSpec() {
        #expect(BovexaTheme.Space.xs == 6)
        #expect(BovexaTheme.Space.sm == 10)
        #expect(BovexaTheme.Space.md == 14)
        #expect(BovexaTheme.Space.lg == 18)
        #expect(BovexaTheme.Space.xl == 24)
        #expect(BovexaTheme.Space.xxl == 32)
    }

    @Test func typeTokensMatchSpec() {
        #expect(BovexaTheme.TypeScale.h1 == 32)
        #expect(BovexaTheme.TypeScale.h2 == 24)
        #expect(BovexaTheme.TypeScale.title == 17)
        #expect(BovexaTheme.TypeScale.body == 14)
        #expect(BovexaTheme.TypeScale.small == 13)
        #expect(BovexaTheme.TypeScale.tiny == 11)
    }

    @Test func categoryColorHasAllFiveCategories() {
        for category in BovexaTheme.Category.allCases {
            _ = BovexaTheme.categoryColor(for: category)
        }
        #expect(BovexaTheme.Category.allCases.count == 5)
    }
}

private extension Int {
    var doubleValue255: Double { Double(self) / 255.0 }
}

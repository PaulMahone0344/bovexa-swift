import XCTest
import SwiftUI
@testable import Bovexa

final class ThemeTests: XCTestCase {
    func test_colorHex_parses6DigitHexWithHash() {
        let color = Color(hex: "#58AEB7")
        let resolved = color.resolve(in: .init())
        XCTAssertEqual(Double(resolved.red), 0x58.doubleValue255, accuracy: 0.01)
        XCTAssertEqual(Double(resolved.green), 0xAE.doubleValue255, accuracy: 0.01)
        XCTAssertEqual(Double(resolved.blue), 0xB7.doubleValue255, accuracy: 0.01)
    }

    func test_colorHex_parsesWithoutHash() {
        let color = Color(hex: "2F858F")
        let resolved = color.resolve(in: .init())
        XCTAssertEqual(Double(resolved.red), 0x2F.doubleValue255, accuracy: 0.01)
        XCTAssertEqual(Double(resolved.green), 0x85.doubleValue255, accuracy: 0.01)
        XCTAssertEqual(Double(resolved.blue), 0x8F.doubleValue255, accuracy: 0.01)
    }

    func test_radiusTokens_matchSpec() {
        XCTAssertEqual(BovexaTheme.Radius.sm, 14)
        XCTAssertEqual(BovexaTheme.Radius.md, 20)
        XCTAssertEqual(BovexaTheme.Radius.lg, 26)
        XCTAssertEqual(BovexaTheme.Radius.pill, 999)
        XCTAssertEqual(BovexaTheme.Radius.phone, 48)
    }

    func test_spaceTokens_matchSpec() {
        XCTAssertEqual(BovexaTheme.Space.xs, 6)
        XCTAssertEqual(BovexaTheme.Space.sm, 10)
        XCTAssertEqual(BovexaTheme.Space.md, 14)
        XCTAssertEqual(BovexaTheme.Space.lg, 18)
        XCTAssertEqual(BovexaTheme.Space.xl, 24)
        XCTAssertEqual(BovexaTheme.Space.xxl, 32)
    }

    func test_typeTokens_matchSpec() {
        XCTAssertEqual(BovexaTheme.TypeScale.h1, 32)
        XCTAssertEqual(BovexaTheme.TypeScale.h2, 24)
        XCTAssertEqual(BovexaTheme.TypeScale.title, 17)
        XCTAssertEqual(BovexaTheme.TypeScale.body, 14)
        XCTAssertEqual(BovexaTheme.TypeScale.small, 13)
        XCTAssertEqual(BovexaTheme.TypeScale.tiny, 11)
    }

    func test_categoryColor_hasAllFiveCategories() {
        XCTAssertNotNil(BovexaTheme.categoryColor(for: .focus))
        XCTAssertNotNil(BovexaTheme.categoryColor(for: .work))
        XCTAssertNotNil(BovexaTheme.categoryColor(for: .social))
        XCTAssertNotNil(BovexaTheme.categoryColor(for: .body))
        XCTAssertNotNil(BovexaTheme.categoryColor(for: .afwezig))
    }
}

private extension Int {
    var doubleValue255: Double { Double(self) / 255.0 }
}

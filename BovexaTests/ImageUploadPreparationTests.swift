import Testing
import Foundation
import UIKit
@testable import Bovexa

/// M11 plak 4f: een gekozen foto ging ongewijzigd omhoog (HEIC/PNG, 3-8 MB) maar
/// werd aangekondigd als "avatar.jpg"/image/jpeg.
struct ImageUploadPreparationTests {
    private func image(width: Int, height: Int) -> Data {
        let size = CGSize(width: width, height: height)
        let rendered = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return rendered.pngData()!
    }

    // MARK: - targetSize

    @Test func aLargeLandscapeImageIsScaledToTheLongestSide() {
        let result = ImageUploadPreparation.targetSize(for: CGSize(width: 4032, height: 3024))
        #expect(result.width == 512)
        #expect(result.height == 384) // verhouding 4:3 blijft
    }

    @Test func aLargePortraitImageIsScaledToTheLongestSide() {
        let result = ImageUploadPreparation.targetSize(for: CGSize(width: 3024, height: 4032))
        #expect(result.height == 512)
        #expect(result.width == 384)
    }

    /// Opblazen kost alleen bytes en levert geen scherpte.
    @Test func anImageThatIsAlreadySmallEnoughIsLeftAlone() {
        let small = CGSize(width: 200, height: 120)
        #expect(ImageUploadPreparation.targetSize(for: small) == small)
    }

    @Test func exactlyAtTheLimitIsLeftAlone() {
        let atLimit = CGSize(width: 512, height: 300)
        #expect(ImageUploadPreparation.targetSize(for: atLimit) == atLimit)
    }

    @Test func aZeroSizedImageDoesNotDivideByZero() {
        #expect(ImageUploadPreparation.targetSize(for: .zero) == .zero)
    }

    // MARK: - jpegData

    @Test func aPngIsConvertedToJpegAndShrunk() {
        let png = image(width: 1600, height: 1200)
        let jpeg = ImageUploadPreparation.jpegData(from: png)

        #expect(jpeg != nil)
        // JPEG-magic: het bestand is écht jpeg, niet een omgelabelde png.
        #expect(jpeg!.prefix(2) == Data([0xFF, 0xD8]))
        #expect(jpeg!.count < png.count)

        let decoded = UIImage(data: jpeg!)
        #expect(decoded?.size.width == 512)
        #expect(decoded?.size.height == 384)
    }

    @Test func unreadableDataGivesNilSoTheCallerCanReport() {
        #expect(ImageUploadPreparation.jpegData(from: Data("geen afbeelding".utf8)) == nil)
    }
}

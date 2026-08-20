import UIKit

/// Klaarmaken van een gekozen foto vóór upload (M11 plak 4f). De PhotosPicker
/// levert de ruwe bestandsdata: een iPhone-foto is HEIC en 3-8 MB, een
/// schermafbeelding is PNG. Die ging ongewijzigd omhoog onder de naam
/// "avatar.jpg" met mime-type image/jpeg — traag op 4G, en een mismatch zodra
/// het PocketBase-veld op mime-types filtert.
enum ImageUploadPreparation {
    /// Langste zijde van de geschaalde afbeelding. 512 is ruim voor een avatar of
    /// bedrijfslogo; die worden nergens groter dan ~120pt getekend.
    static let maxDimension: CGFloat = 512
    static let jpegQuality: CGFloat = 0.8

    /// Doelmaat met behoud van de verhouding. Een afbeelding die al klein genoeg
    /// is wordt niet opgeblazen — dat kost alleen bytes en levert geen scherpte.
    static func targetSize(for size: CGSize, maxDimension: CGFloat = ImageUploadPreparation.maxDimension) -> CGSize {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return size }
        let scale = maxDimension / longest
        return CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    }

    /// Ruwe bestandsdata → JPEG van ten hoogste `maxDimension` px. Geeft nil als de
    /// data geen leesbare afbeelding is; de aanroeper hoort dat te melden in plaats
    /// van stil niets te doen.
    static func jpegData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let target = targetSize(for: image.size)
        guard target != image.size else { return image.jpegData(compressionQuality: jpegQuality) }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: jpegQuality)
    }
}

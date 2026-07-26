import Foundation

/// Zet een geplakte agenda-link om naar `webcal://` (m8, klantverzoek 26 juli,
/// variant A) — zelfde mechanisme als de bestaande knop "In iPhone Agenda" bij
/// Bedrijf (m5): de link wordt aan iOS doorgegeven, de app leest de feed zelf niet
/// uit. Accepteert http(s):// en webcal://; al het andere is ongeldig.
enum WebcalLinkConverter {
    private static let acceptedSchemes: Set<String> = ["http", "https", "webcal"]

    static func convert(_ input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), let host = url.host, !host.isEmpty else { return nil }
        guard acceptedSchemes.contains(scheme) else { return nil }
        guard scheme != "webcal" else { return url }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "webcal"
        return components?.url
    }
}

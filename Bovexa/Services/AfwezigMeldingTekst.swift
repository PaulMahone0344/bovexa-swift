import Foundation

/// De twee regels van een doorgegeven melding in de lijst onder de knoppen:
/// welke dag(en), en welke tijden. Los van de view zodat er tests op kunnen.
enum AfwezigMeldingTekst {
    private static let dagFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "EEEE d MMMM"
        return formatter
    }()

    private static let korteDagFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private static let tijdFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// Eén dag voluit ("woensdag 26 augustus"), een periode kort met het aantal
    /// erachter ("26 aug — 30 aug · 5 dagen") — voluit werd te lang voor de regel.
    static func dagen(_ melding: Beschikbaarheidsmelding, calendar: Calendar = .current) -> String {
        let dagen = melding.dagen.sorted()
        guard let eerste = dagen.first else { return "" }
        if dagen.count == 1 {
            return dagFormatter.string(from: eerste).capitalizedFirst
        }
        // Losse dagen mogen, dus ze staan er allemaal; bij meer dan vier wordt de
        // regel te lang en volstaat het aantal met de eerste en laatste erbij.
        if dagen.count <= 4 {
            return dagen.map { korteDagFormatter.string(from: $0) }.joined(separator: ", ")
        }
        let laatste = dagen[dagen.count - 1]
        return "\(dagen.count) dagen · \(korteDagFormatter.string(from: eerste)) t/m \(korteDagFormatter.string(from: laatste))"
    }

    /// "Hele dag" of "09:00 – 17:00". De tijden gelden voor elke gekozen dag.
    static func tijden(_ melding: Beschikbaarheidsmelding) -> String {
        guard !melding.heleDag, let start = melding.startTijd, let eind = melding.eindTijd else {
            return "Hele dag"
        }
        return "\(tijdFormatter.string(from: start)) – \(tijdFormatter.string(from: eind))"
    }
}

private extension String {
    /// `DateFormatter` levert "woensdag"; aan het begin van een regel hoort een
    /// hoofdletter. `capitalized` zou er "Woensdag 26 Augustus" van maken.
    var capitalizedFirst: String {
        guard let eerste = first else { return self }
        return eerste.uppercased() + dropFirst()
    }
}

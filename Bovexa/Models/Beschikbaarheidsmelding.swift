import Foundation

/// Wat iemand doorgeeft op het beschikbaarheidsscherm: één melding per keer dat
/// hij op "Beschikbaarheid doorgeven" of "Afwezigheid doorgeven" tikt.
enum MeldSoort: String, Codable, Equatable {
    case beschikbaar
    case afwezig

    var knopLabel: String {
        switch self {
        case .beschikbaar: return "Beschikbaarheid doorgeven"
        case .afwezig: return "Afwezigheid doorgeven"
        }
    }
}

/// Een doorgegeven periode, zoals hij onder de knoppen in de lijst komt te staan.
/// `reden` is leeg bij een beschikbaarheidsmelding — die heeft er geen.
struct Beschikbaarheidsmelding: Codable, Equatable, Identifiable {
    let id: String
    let soort: MeldSoort
    let reden: String
    let titel: String
    /// Precies de aangetikte dagen. Losse dagen mogen, dus een eerste en laatste
    /// datum zeggen niet genoeg: 26 en 30 augustus is twee dagen, geen vijf.
    let dagen: [Date]
    /// De afspraken die hierbij op de server zijn gezet, één per dag. Nodig om ze
    /// weer weg te kunnen halen als de gebruiker de melding intrekt.
    var eventIds: [String] = []
    let heleDag: Bool
    /// Alleen gevuld als `heleDag` uit staat; anders is de tijd niet doorgegeven.
    let startTijd: Date?
    let eindTijd: Date?
    let gemeldOp: Date

    var van: Date { dagen.min() ?? gemeldOp }
    var tot: Date { dagen.max() ?? gemeldOp }

    /// Het label rechts in de lijst: "Beschikbaar" of de reden ("Ziek", of bij
    /// "Anders" de toelichting die de gebruiker zelf typte).
    var soortLabel: String {
        soort == .beschikbaar ? "Beschikbaar" : titel
    }
}

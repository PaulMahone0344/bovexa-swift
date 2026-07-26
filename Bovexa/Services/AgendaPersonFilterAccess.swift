import Foundation

/// Mag deze gebruiker de agenda van collega's bekijken (m10)?
///
/// Geen beveiliging: de server bepaalt al wat je binnenhaalt, en wat je niet mag
/// zien zit ook niet in de respons. Dit voorkomt alleen een misleidende knop —
/// een lijst met namen aanbieden die daarna een leeg raster oplevert.
enum AgendaPersonFilterAccess {
    static func isAllowed(userId: String, members: [Member]) -> Bool {
        guard let me = members.first(where: { $0.userId == userId }) else {
            // Ledenlijst nog niet binnen: liever geen knop dan een knop die
            // een tel later weer verdwijnt.
            return false
        }
        // Een admin beheert de rechten van anderen en kan het vinkje toch zelf
        // zetten; hem uitsluiten van de agenda van zijn eigen team is onlogisch.
        return me.role == .admin || me.magAgendaAnderenZien
    }
}

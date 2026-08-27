import Foundation

/// Wat één collega heeft gedaan en wanneer hij weg was, afgeleid uit de agenda.
///
/// Er is geen urenregistratie en geen verlofadministratie op de server (dezelfde
/// valkuil als bij ContactInzet): alles komt uit agenda_events. Een afspraak telt
/// mee als de collega hem zelf heeft gezet, of als hij erop is toegewezen én hem
/// heeft aangenomen — een uitnodiging die hij heeft geweigerd zegt niets over zijn
/// inzet. Externe agenda's tellen niet mee: die komen niet uit dit bedrijf.
enum MedewerkerInzet {
    /// Eén dag die op zijn naam staat.
    struct Dag: Identifiable, Equatable {
        let id: String
        let titel: String
        let start: Date
        let einde: Date?
        let heleDag: Bool
        /// Voorbij: telt als gewerkt. Anders staat het nog ingepland.
        let geweest: Bool

        /// Zonder eindtijd of bij een hele dag valt er niets te tellen — hoe lang
        /// iemand er die dag was staat nergens.
        var minuten: Int {
            guard !heleDag, let einde else { return 0 }
            return max(0, Int(einde.timeIntervalSince(start) / 60))
        }
    }

    /// Eén keer afwezig, met de reden zoals de collega die zelf opgaf.
    struct Afwezig: Identifiable, Equatable {
        let id: String
        /// De titel van het blok: "Vakantie", "Ziek", of wat er bij "Anders" is getypt.
        let reden: String
        /// De toelichting uit het opmerkingenveld, als die er is.
        let toelichting: String?
        let start: Date
        let einde: Date?
        let heleDag: Bool
    }

    /// Alles wat op naam van deze collega staat, nieuwste bovenaan, gesplitst in
    /// werk en afwezigheid.
    static func overzicht(
        events: [AgendaEvent],
        userId: String,
        now: Date
    ) -> (dagen: [Dag], afwezig: [Afwezig]) {
        let eigen = events.filter { event in
            guard !event.isExternal else { return false }
            if event.owner == userId { return true }
            // Toegewezen aan hem: alleen als hij het heeft aangenomen. Een openstaande
            // of geweigerde uitnodiging is geen ingeplande dag.
            return event.assignee.contains(userId) && event.assigneeStatus[userId] == "accepted"
        }

        let dagen = eigen
            .filter { $0.category != .afwezig }
            .map { event in
                Dag(
                    id: event.id,
                    titel: event.title,
                    start: event.start,
                    einde: event.end,
                    heleDag: event.allDay,
                    geweest: (event.end ?? event.start) < now
                )
            }
            .sorted { $0.start > $1.start }

        let afwezig = eigen
            .filter { $0.category == .afwezig }
            .map { event in
                let notitie = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
                return Afwezig(
                    id: event.id,
                    reden: event.title.isEmpty ? "Afwezig" : event.title,
                    toelichting: (notitie?.isEmpty ?? true) ? nil : notitie,
                    start: event.start,
                    einde: event.end,
                    heleDag: event.allDay
                )
            }
            .sorted { $0.start > $1.start }

        return (dagen, afwezig)
    }

    static func minuten(_ dagen: [Dag], geweest: Bool) -> Int {
        dagen.filter { $0.geweest == geweest }.reduce(0) { $0 + $1.minuten }
    }

    /// Hoeveel losse kalenderdagen er in de lijst zitten. Twee afspraken op
    /// dezelfde dag zijn één werkdag, geen twee.
    static func aantalDagen(_ dagen: [Dag], geweest: Bool, calendar: Calendar = .current) -> Int {
        Set(dagen.filter { $0.geweest == geweest }.map { calendar.startOfDay(for: $0.start) }).count
    }

    /// Hoeveel dagen deze collega in totaal weg was, losse dagen geteld — een blok
    /// van maandag tot en met vrijdag is vijf dagen, geen één.
    static func afwezigeDagen(_ afwezig: [Afwezig], calendar: Calendar = .current) -> Int {
        var dagen: Set<Date> = []
        for blok in afwezig {
            let eerste = calendar.startOfDay(for: blok.start)
            let laatste = calendar.startOfDay(for: blok.einde ?? blok.start)
            var dag = eerste
            while dag <= laatste {
                dagen.insert(dag)
                guard let volgende = calendar.date(byAdding: .day, value: 1, to: dag) else { break }
                dag = volgende
            }
        }
        return dagen.count
    }

    /// Hoe vaak per reden — "Ziek 3×, Vakantie 1×", zodat je een patroon ziet
    /// zonder de hele lijst af te gaan. Meeste bovenaan.
    static func perReden(_ afwezig: [Afwezig]) -> [(reden: String, aantal: Int)] {
        var telling: [String: Int] = [:]
        for blok in afwezig {
            telling[blok.reden, default: 0] += 1
        }
        return telling
            .map { (reden: $0.key, aantal: $0.value) }
            .sorted { $0.aantal == $1.aantal ? $0.reden < $1.reden : $0.aantal > $1.aantal }
    }

    /// "6 uur 30 min" — zelfde vorm als ContactInzet.urenTekst.
    static func urenTekst(minuten: Int) -> String {
        ContactInzet.urenTekst(minuten: minuten)
    }
}

import Foundation

/// Wie hoort bij een afspraak (m8): het gekoppelde contact wint van de losse
/// tekst. Oude afspraken zonder contact (valkuil D) tonen gewoon hun klantnaam.
enum ContactDisplay {
    static func naam(for event: AgendaEvent) -> String? {
        if let contactNaam = event.expand?.contact?.naam, !contactNaam.isEmpty {
            return contactNaam
        }
        return event.klantNaam
    }

    static func telefoon(for event: AgendaEvent) -> String? {
        if let contactTelefoon = event.expand?.contact?.telefoon, !contactTelefoon.isEmpty {
            return contactTelefoon
        }
        return event.klantTelefoon
    }
}

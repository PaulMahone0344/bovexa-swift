import Foundation

/// Onthoudt wat iemand op het beschikbaarheidsscherm heeft doorgegeven, zodat de
/// lijst onder de knoppen na een herstart nog klopt. De blokken zelf staan gewoon
/// als afspraak op de server; alleen "dit heb ík doorgegeven, en waarom" is daar
/// niet uit terug te lezen — `raw_input` komt niet mee in `AgendaEvent`.
///
/// Tijdelijk, net als `HerinneringStore` en `ContactOrgStore`: zodra de server een
/// eigen collectie voor beschikbaarheid heeft, wint die en mag dit weg.
@MainActor
final class BeschikbaarheidStore: ObservableObject {
    static let shared = BeschikbaarheidStore()

    private static let key = "bovexaflow_beschikbaarheid"
    /// Meldingen die meer dan een halfjaar voorbij zijn, ruimt de app op — anders
    /// groeit de lijst eindeloos door.
    private static let bewaarDagen = 183

    @Published private(set) var meldingen: [Beschikbaarheidsmelding] = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        meldingen = laad()
    }

    /// Wat er nog komt of vandaag speelt, nieuwste periode bovenaan.
    func komende(nu: Date = Date(), calendar: Calendar = .current) -> [Beschikbaarheidsmelding] {
        let vandaag = calendar.startOfDay(for: nu)
        return meldingen
            .filter { $0.tot >= vandaag }
            .sorted { $0.van < $1.van }
    }

    func voegToe(_ melding: Beschikbaarheidsmelding) {
        meldingen.append(melding)
        bewaar()
    }

    func verwijder(_ id: String) {
        guard let index = meldingen.firstIndex(where: { $0.id == id }) else { return }
        meldingen.remove(at: index)
        bewaar()
    }

    /// Bij uitloggen: de meldingen van de vorige gebruiker horen niet bij de
    /// volgende die op dit toestel inlogt.
    func wisAlles() {
        meldingen = []
        defaults.removeObject(forKey: Self.key)
    }

    private func laad() -> [Beschikbaarheidsmelding] {
        guard let data = defaults.data(forKey: Self.key),
              let waarden = try? JSONDecoder().decode([Beschikbaarheidsmelding].self, from: data)
        else { return [] }
        let grens = Calendar.current.date(byAdding: .day, value: -Self.bewaarDagen, to: Date()) ?? Date.distantPast
        return waarden.filter { $0.tot >= grens }
    }

    private func bewaar() {
        guard let data = try? JSONEncoder().encode(meldingen) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

import Foundation

/// Eén regel in de kaart "Dagtaken" op Vandaag. Die kaart toonde alleen lokale
/// dagtaken (PlanningNote); sinds 25 augustus staan de bedrijfstaken er ook in, en
/// die zijn AgendaTask. Dit tussenmodel houdt de kaart onwetend van dat verschil en
/// draagt het bronlabel dat de twee lijsten uit elkaar houdt.
struct DagtaakRegel: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    /// "Privé" of de bedrijfsnaam. Nil als er geen bedrijf is: dan valt er niets te
    /// onderscheiden en is het label alleen ruis.
    let bron: String?

    init(id: String, title: String, body: String, bron: String?) {
        self.id = id
        self.title = title
        self.body = body
        self.bron = bron
    }

    init(note: PlanningNote, bron: String?) {
        self.init(id: note.id, title: note.title, body: note.body, bron: bron)
    }

    init(task: AgendaTask, bron: String?) {
        self.init(id: task.id, title: task.title, body: task.notes ?? "", bron: bron)
    }
}

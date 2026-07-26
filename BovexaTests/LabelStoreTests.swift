import Testing
@testable import Bovexa

struct LabelStoreTests {
    private func label(_ id: String, naam: String, kleur: String, volgorde: Int) -> AgendaLabel {
        AgendaLabel(id: id, org: "org1", naam: naam, kleur: kleur, volgorde: volgorde)
    }

    @Test func labelForKnownIdReturnsLabel() {
        let store = LabelStore()
        store.prime(labels: [label("l1", naam: "VSB", kleur: "#E08A3C", volgorde: 0)])
        #expect(store.label(for: "l1")?.naam == "VSB")
    }

    @Test func labelForUnknownIdReturnsNil() {
        let store = LabelStore()
        store.prime(labels: [label("l1", naam: "VSB", kleur: "#E08A3C", volgorde: 0)])
        #expect(store.label(for: "onbekend") == nil)
    }

    @Test func labelForNilIdReturnsNil() {
        let store = LabelStore()
        #expect(store.label(for: nil) == nil)
    }

    @Test func colorForKnownIdReturnsParsedColor() {
        let store = LabelStore()
        store.prime(labels: [label("l1", naam: "VSB", kleur: "#E08A3C", volgorde: 0)])
        #expect(store.color(for: "l1") != nil)
    }

    @Test func colorForUnknownIdReturnsNil() {
        let store = LabelStore()
        #expect(store.color(for: "onbekend") == nil)
    }

    @Test func addAppendsNewLabelAndKeepsVolgordeOrder() {
        let store = LabelStore()
        store.prime(labels: [label("l1", naam: "Eerste", kleur: "#D6524B", volgorde: 0)])
        store.add(label("l2", naam: "Tweede", kleur: "#4F9E5C", volgorde: 1))
        #expect(store.orderedLabels.map(\.id) == ["l1", "l2"])
        #expect(store.label(for: "l2")?.naam == "Tweede")
    }

    @Test func updateReplacesExistingLabelInPlace() {
        let store = LabelStore()
        store.prime(labels: [label("l1", naam: "Oud", kleur: "#D6524B", volgorde: 0)])
        store.update(label("l1", naam: "Nieuw", kleur: "#4F9E5C", volgorde: 0))
        #expect(store.label(for: "l1")?.naam == "Nieuw")
        #expect(store.label(for: "l1")?.kleur == "#4F9E5C")
        #expect(store.orderedLabels.count == 1)
    }

    @Test func removeDropsLabelFromStoreAndOrderedList() {
        let store = LabelStore()
        store.prime(labels: [
            label("l1", naam: "Eerste", kleur: "#D6524B", volgorde: 0),
            label("l2", naam: "Tweede", kleur: "#4F9E5C", volgorde: 1),
        ])
        store.remove(id: "l1")
        #expect(store.label(for: "l1") == nil)
        #expect(store.orderedLabels.map(\.id) == ["l2"])
    }

    @Test func orderedLabelsPreservesVolgorde() {
        let store = LabelStore()
        store.prime(labels: [
            label("l3", naam: "Derde", kleur: "#3E87D6", volgorde: 2),
            label("l1", naam: "Eerste", kleur: "#D6524B", volgorde: 0),
            label("l2", naam: "Tweede", kleur: "#4F9E5C", volgorde: 1),
        ])
        #expect(store.orderedLabels.map(\.id) == ["l1", "l2", "l3"])
    }
}

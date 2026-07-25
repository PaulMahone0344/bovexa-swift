import Testing
import Foundation
@testable import Bovexa

struct PlanningNoteFactoryTests {
    @Test func emptyTextReturnsNil() {
        #expect(PlanningNoteFactory.make(text: "") == nil)
    }

    @Test func whitespaceOnlyTextReturnsNil() {
        #expect(PlanningNoteFactory.make(text: "   \n\t\n  ") == nil)
    }

    @Test func singleLineBecomesTitleWithEmptyBody() {
        let note = PlanningNoteFactory.make(text: "Bellen met klant")
        #expect(note?.title == "Bellen met klant")
        #expect(note?.body == "")
    }

    @Test func firstLineIsTitleRestIsBody() {
        let note = PlanningNoteFactory.make(text: "Offerte maken\nVoor de nieuwe klant\nDeadline vrijdag")
        #expect(note?.title == "Offerte maken")
        #expect(note?.body == "Voor de nieuwe klant\nDeadline vrijdag")
    }

    @Test func extraWhitespaceInTitleIsCollapsed() {
        let note = PlanningNoteFactory.make(text: "  Bellen   met    klant  ")
        #expect(note?.title == "Bellen met klant")
    }

    @Test func blankLinesBetweenContentAreDropped() {
        let note = PlanningNoteFactory.make(text: "Titel\n\n\nRegel A\n\nRegel B")
        #expect(note?.title == "Titel")
        #expect(note?.body == "Regel A\nRegel B")
    }

    @Test func newNoteStartsUndoneAndUnarchived() {
        let note = PlanningNoteFactory.make(text: "Taak")
        #expect(note?.done == false)
        #expect(note?.archived == false)
    }

    @Test func updateReplacesTitleAndBodyKeepingIdAndDoneAndArchived() {
        let original = PlanningNote(
            id: "n1", title: "Oud", body: "Oude tekst", done: true,
            createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0), archived: true
        )
        let updated = PlanningNoteFactory.update(original, text: "Nieuw\nNieuwe tekst")
        #expect(updated?.id == "n1")
        #expect(updated?.title == "Nieuw")
        #expect(updated?.body == "Nieuwe tekst")
        #expect(updated?.done == true)
        #expect(updated?.archived == true)
        #expect(updated?.createdAt == original.createdAt)
    }

    @Test func updateWithEmptyTextReturnsNil() {
        let original = PlanningNote(
            id: "n1", title: "Oud", body: "", done: false,
            createdAt: Date(), updatedAt: Date(), archived: false
        )
        #expect(PlanningNoteFactory.update(original, text: "   ") == nil)
    }

    @Test func draftTextJoinsTitleAndBodyForEditing() {
        let note = PlanningNote(
            id: "n1", title: "Titel", body: "Regel A\nRegel B", done: false,
            createdAt: Date(), updatedAt: Date(), archived: false
        )
        #expect(PlanningNoteFactory.draftText(for: note) == "Titel\nRegel A\nRegel B")
    }

    @Test func draftTextWithEmptyBodyIsJustTitle() {
        let note = PlanningNote(
            id: "n1", title: "Titel", body: "", done: false,
            createdAt: Date(), updatedAt: Date(), archived: false
        )
        #expect(PlanningNoteFactory.draftText(for: note) == "Titel")
    }
}

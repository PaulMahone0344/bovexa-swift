import Testing
@testable import Bovexa

struct PlannerDetailsSummaryTests {
    @Test func showsCompanyNameForACompanyAppointment() {
        let text = PlannerDetailsSummary.text(
            visibility: "company", companyName: "Bovexa", assigneeCount: 0,
            labelName: nil, contactName: nil, reminderMin: 0
        )

        #expect(text == "Bovexa")
    }

    @Test func fallsBackToBedrijfWithoutACompanyName() {
        let text = PlannerDetailsSummary.text(
            visibility: "company", companyName: nil, assigneeCount: 0,
            labelName: nil, contactName: nil, reminderMin: 0
        )

        #expect(text == "Bedrijf")
    }

    /// De samenvatting moet alles noemen wat de gebruiker straks niet meer ziet
    /// zodra het blok dicht staat — anders klapt hij het uit "om even te kijken".
    @Test func joinsEveryChosenPartWithDots() {
        let text = PlannerDetailsSummary.text(
            visibility: "private", companyName: "Bovexa", assigneeCount: 2,
            labelName: "VSB", contactName: "Jan de Vries", reminderMin: 15
        )

        #expect(text == "Privé · Jij + 2 · VSB · Jan de Vries · 15 min vooraf")
    }

    /// Niets gekozen: geen lege bolletjes achter elkaar, maar één rustige regel.
    @Test func withoutChoicesOnlyTheVisibilityRemains() {
        let text = PlannerDetailsSummary.text(
            visibility: "private", companyName: nil, assigneeCount: 0,
            labelName: nil, contactName: nil, reminderMin: 0
        )

        #expect(text == "Privé")
    }

    /// Zonder bedrijf is er geen zichtbaarheid te kiezen; dan blijft alleen de
    /// herinnering over en mag de regel daarmee beginnen.
    @Test func withoutCompanyTheReminderCarriesTheLine() {
        let text = PlannerDetailsSummary.text(
            visibility: nil, companyName: nil, assigneeCount: 0,
            labelName: nil, contactName: nil, reminderMin: 60
        )

        #expect(text == "1 uur vooraf")
    }

    @Test func withoutAnythingAtAllTheLineIsEmpty() {
        let text = PlannerDetailsSummary.text(
            visibility: nil, companyName: nil, assigneeCount: 0,
            labelName: nil, contactName: nil, reminderMin: 0
        )

        #expect(text.isEmpty)
    }
}

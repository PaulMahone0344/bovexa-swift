import Foundation

/// Meldingen-scherm: twee secties in één (valkuil D) — toewijzingen die op jouw
/// akkoord wachten (hergebruikt AssignmentHelpers/EventRepository.respondToAssignment
/// uit m2, geen tweede versie) en de bedrijfsmededelingen. Openen zet de
/// ongelezen-stip op Profiel uit (valkuil E, via NoticesSeenStore).
@MainActor
final class MeldingenViewModel: ObservableObject {
    @Published private(set) var pending: [AgendaEvent] = []
    /// Toewijzingen waarop nooit geantwoord is en waarvan de afspraak al voorbij
    /// is. Accepteren of weigeren zegt daar niets meer; ze staan apart en zonder
    /// knoppen, zodat je wel ziet dat er iets langs is gekomen.
    @Published private(set) var expired: [AgendaEvent] = []
    @Published private(set) var notices: [Notice] = []
    @Published private(set) var role: CompanyRole?
    @Published private(set) var loaded = false
    @Published var composeOpen = false
    @Published var composeTitle = ""
    @Published var composeBody = ""
    @Published private(set) var posting = false
    @Published var postFailedMessage: String?
    @Published private(set) var answeringId: String?
    @Published var respondFailedAlert = false
    @Published var deleteFailedMessage: String?

    private let userId: String
    private let orgId: String?
    private let token: String

    private let eventRepository: EventRepository
    private let noticeRepository: NoticeRepository
    private let companyRepository: CompanyRepository
    private let seenStore: NoticesSeenStore
    private let now: () -> Date

    init(
        userId: String, orgId: String?, token: String,
        eventRepository: EventRepository = EventRepository(),
        noticeRepository: NoticeRepository = NoticeRepository(),
        companyRepository: CompanyRepository = CompanyRepository(),
        seenStore: NoticesSeenStore = NoticesSeenStore(),
        now: @escaping () -> Date = Date.init
    ) {
        self.now = now
        self.userId = userId
        self.orgId = orgId
        self.token = token
        self.eventRepository = eventRepository
        self.noticeRepository = noticeRepository
        self.companyRepository = companyRepository
        self.seenStore = seenStore
    }

    /// Valkuil D/E: plus-knop alleen voor admin/manager — de server checkt dit
    /// hoe dan ook, maar de knop moet ook client-side verborgen zijn.
    var canPost: Bool { role == .admin || role == .manager }
    var isEmpty: Bool { loaded && pending.isEmpty && expired.isEmpty && notices.isEmpty }
    var canSubmit: Bool { !composeBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !posting }

    func canDelete(_ notice: Notice) -> Bool { notice.author == userId }

    func load() async {
        if let events = try? await eventRepository.fetchAllEvents(userId: userId, orgId: orgId, token: token) {
            let moment = now()
            pending = AssignmentHelpers.pendingEvents(events, userId: userId, now: moment)
            expired = AssignmentHelpers.expiredPendingEvents(events, userId: userId, now: moment)
        } else {
            pending = []
            expired = []
        }

        guard let orgId else {
            notices = []
            loaded = true
            return
        }

        if let items = try? await noticeRepository.fetchNotices(orgId: orgId, token: token) {
            notices = items
        } else {
            notices = []
        }
        loaded = true
        seenStore.markSeen(userId: userId)

        if let membership = try? await companyRepository.listMembers(token: token) {
            role = membership.items.first { $0.userId == userId }?.role
        } else {
            role = nil
        }
    }

    func submit() async {
        guard canSubmit else { return }
        let text = composeBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = composeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        posting = true
        defer { posting = false }
        do {
            let created = try await noticeRepository.createNotice(title: title, body: text, token: token)
            notices.insert(created, at: 0)
            composeTitle = ""
            composeBody = ""
            composeOpen = false
        } catch {
            postFailedMessage = "Plaatsen mislukt. Probeer het nog een keer."
        }
    }

    func deleteNotice(_ notice: Notice) async {
        guard canDelete(notice) else { return }
        do {
            try await noticeRepository.deleteNotice(id: notice.id, token: token)
            notices.removeAll { $0.id == notice.id }
        } catch {
            deleteFailedMessage = "Kon de mededeling niet verwijderen."
        }
    }

    /// Valkuil B: reageert exact als EventDetailViewModel.respond — optimistisch uit
    /// de wachtlijst, terugzetten bij falen.
    func respond(_ event: AgendaEvent, status: String) async {
        guard answeringId == nil else { return }
        answeringId = event.id
        let rest = pending.filter { $0.id != event.id }
        pending = rest
        do {
            _ = try await eventRepository.respondToAssignment(event: event, userId: userId, status: status, token: token)
        } catch {
            pending = [event] + rest
            respondFailedAlert = true
        }
        answeringId = nil
    }
}

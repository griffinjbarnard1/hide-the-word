import Foundation
import ScriptureMemory

enum SessionDraftPhase: String, Codable {
    case display
    case recall
    case rating
    case complete
}

enum SessionDraftMode: String, Codable {
    case daily
    case planDaily
    case focusedPractice
}

struct SessionDraftPlanContext: Codable, Sendable, Hashable {
    var planID: UUID
    var planTitle: String
    var dayNumber: Int
    var dayTitle: String
    var dayGoal: PlanDayGoal
}

struct SessionDraft: Codable, Sendable {
    var collectionID: UUID
    var items: [SessionItem]
    var currentIndex: Int
    var phase: SessionDraftPhase
    var restudiedUnitIDs: Set<UUID>
    var startedAt: Date
    var mode: SessionDraftMode = .daily
    var focusReference: String?
    var planContext: SessionDraftPlanContext?

    var isFinished: Bool {
        phase == .complete || currentIndex >= items.count
    }

    var isFocusedPractice: Bool {
        mode == .focusedPractice
    }

    var isPlanDaily: Bool {
        mode == .planDaily
    }
}

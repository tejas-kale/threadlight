public final class MemoryBriefStore: BriefStore {
    private var briefs: [BriefDay: CanonicalBrief] = [:]

    public init() {}

    public func brief(for day: BriefDay) -> CanonicalBrief? { briefs[day] }
    public func save(_ brief: CanonicalBrief) { briefs[brief.day] = brief }
}

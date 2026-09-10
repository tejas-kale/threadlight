import Foundation

public struct BriefDay: Equatable, Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(now: Date, timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        year = parts.year!
        month = parts.month!
        day = parts.day!
    }
}

public struct SourceObservation: Equatable, Sendable {
    public let title: String
    public let startsAt: Date
    public let endsAt: Date
    public let evidenceLink: URL

    public init(title: String, startsAt: Date, endsAt: Date? = nil, evidenceLink: URL) {
        self.title = title
        self.startsAt = startsAt
        self.endsAt = endsAt ?? startsAt.addingTimeInterval(0.001)
        self.evidenceLink = evidenceLink
    }
}

public enum Source: String, Equatable, Sendable {
    case calendar = "Calendar"
}

public enum SourceState: String, Equatable, Sendable {
    case available
    case denied
    case failed
}

public struct SourceStatus: Equatable, Sendable {
    public let source: Source
    public let state: SourceState
    public let refreshedAt: Date?

    public init(source: Source, state: SourceState, refreshedAt: Date?) {
        self.source = source
        self.state = state
        self.refreshedAt = refreshedAt
    }
}

public struct SourceReport: Equatable, Sendable {
    public let status: SourceStatus
    public let observations: [SourceObservation]

    public init(status: SourceStatus, observations: [SourceObservation]) {
        self.status = status
        self.observations = observations
    }
}

public struct CanonicalBrief: Equatable, Sendable {
    public let day: BriefDay
    public let markdown: String

    public init(day: BriefDay, markdown: String) {
        self.day = day
        self.markdown = markdown
    }
}

public enum BriefRunOutcome: String, Equatable, Sendable {
    case retrieved
    case completed
    case notCompleted = "not completed"
}

public struct BriefRunResult: Equatable, Sendable {
    public let outcome: BriefRunOutcome
    public let brief: CanonicalBrief?
    public let statuses: [SourceStatus]

    public init(outcome: BriefRunOutcome, brief: CanonicalBrief?, statuses: [SourceStatus]) {
        self.outcome = outcome
        self.brief = brief
        self.statuses = statuses
    }
}

public protocol SourceAdapter: AnyObject {
    func observations(in window: DateInterval) -> SourceReport
}

public protocol BriefStore: AnyObject {
    func brief(for day: BriefDay) -> CanonicalBrief?
    func save(_ brief: CanonicalBrief)
}

public struct ApplicationCore {
    private let adapter: SourceAdapter
    private let store: BriefStore

    public init(adapter: SourceAdapter, store: BriefStore) {
        self.adapter = adapter
        self.store = store
    }

    public func run(now: Date = .now, timeZone: TimeZone = .current) -> BriefRunResult {
        let day = BriefDay(now: now, timeZone: timeZone)
        let window = Self.window(now: now, timeZone: timeZone)
        let sourceReport = adapter.observations(in: window)
        let report = SourceReport(
            status: sourceReport.status,
            observations: sourceReport.observations.filter {
                $0.endsAt > window.start && $0.startsAt < window.end
            }
        )
        if let brief = store.brief(for: day) {
            return BriefRunResult(outcome: .retrieved, brief: brief, statuses: [report.status])
        }
        guard report.status.state == .available else {
            return BriefRunResult(outcome: .notCompleted, brief: nil, statuses: [report.status])
        }
        let brief = CanonicalBrief(day: day, markdown: Self.render(report: report, timeZone: timeZone))
        store.save(brief)
        return BriefRunResult(outcome: .completed, brief: brief, statuses: [report.status])
    }

    private static func window(now: Date, timeZone: TimeZone) -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start)!
        let end = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow)!
        return DateInterval(start: start, end: end)
    }

    private static func render(report: SourceReport, timeZone: TimeZone) -> String {
        let date = DateFormatter()
        date.timeZone = timeZone
        date.dateFormat = "HH:mm"
        let items = report.observations.sorted {
            ($0.startsAt, $0.endsAt, $0.title, $0.evidenceLink.absoluteString)
                < ($1.startsAt, $1.endsAt, $1.title, $1.evidenceLink.absoluteString)
        }.map {
            let title = $0.title.split(whereSeparator: \.isNewline).joined(separator: " ")
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "[", with: "\\[")
                .replacingOccurrences(of: "]", with: "\\]")
            return "- \(date.string(from: $0.startsAt)) [\(title)](<\($0.evidenceLink.absoluteString)>)"
        }
        let refreshed = report.status.refreshedAt?.formatted(.iso8601) ?? "unknown"
        return (["# Threadlight", "", "## Calendar"] + items + ["", "Status: \(report.status.state.rawValue); refreshed: \(refreshed)"]).joined(separator: "\n")
    }
}

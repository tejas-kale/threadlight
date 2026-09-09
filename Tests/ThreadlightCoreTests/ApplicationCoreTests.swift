import Foundation
import Testing
@testable import ThreadlightCore

@Test func completedRunUsesCurrentTimeZoneWindowAndPreservesEvidence() throws {
    let zone = TimeZone(identifier: "Europe/Berlin")!
    let now = try Date.ISO8601FormatStyle().parse("2026-09-09T20:00:00Z")
    let evidence = URL(string: "eventkit://event/standup")!
    let adapter = ControlledAdapter(report: SourceReport(
        status: SourceStatus(source: .calendar, state: .available, refreshedAt: now),
        observations: [SourceObservation(title: "Stand-up", startsAt: now, evidenceLink: evidence)]
    ))
    let store = ControlledStore()

    let result = ApplicationCore(adapter: adapter, store: store).run(now: now, timeZone: zone)

    #expect(result.outcome == .completed)
    #expect(result.brief?.markdown.contains("[Stand-up](<eventkit://event/standup>)") == true)
    #expect(result.statuses == [SourceStatus(source: .calendar, state: .available, refreshedAt: now)])
    #expect(store.saved == result.brief)
}

@Test func eventsAtTenAndLaterAreExcluded() throws {
    let zone = TimeZone(identifier: "Europe/Berlin")!
    let now = try Date.ISO8601FormatStyle().parse("2026-09-09T08:00:00Z")
    let beforeTen = try Date.ISO8601FormatStyle().parse("2026-09-10T07:59:00Z")
    let atTen = try Date.ISO8601FormatStyle().parse("2026-09-10T08:00:00Z")
    let adapter = ControlledAdapter(report: SourceReport(
        status: SourceStatus(source: .calendar, state: .available, refreshedAt: now),
        observations: [
            SourceObservation(title: "Before", startsAt: beforeTen, evidenceLink: URL(string: "eventkit://event/before")!),
            SourceObservation(title: "At", startsAt: atTen, evidenceLink: URL(string: "eventkit://event/at")!),
        ]
    ))

    let result = ApplicationCore(adapter: adapter, store: ControlledStore()).run(now: now, timeZone: zone)

    #expect(result.brief?.markdown.contains("[Before]") == true)
    #expect(result.brief?.markdown.contains("[At]") == false)
}

@Test func daylightSavingWindowEndsAtLocalTen() throws {
    let zone = TimeZone(identifier: "Europe/Berlin")!
    let now = try Date.ISO8601FormatStyle().parse("2026-03-28T11:00:00Z")
    let beforeTen = try Date.ISO8601FormatStyle().parse("2026-03-29T07:59:00Z")
    let atTen = try Date.ISO8601FormatStyle().parse("2026-03-29T08:00:00Z")
    let adapter = ControlledAdapter(report: SourceReport(
        status: SourceStatus(source: .calendar, state: .available, refreshedAt: now),
        observations: [
            SourceObservation(title: "Before", startsAt: beforeTen, evidenceLink: URL(string: "eventkit://event/before")!),
            SourceObservation(title: "At", startsAt: atTen, evidenceLink: URL(string: "eventkit://event/at")!),
        ]
    ))

    let result = ApplicationCore(adapter: adapter, store: ControlledStore()).run(now: now, timeZone: zone)

    #expect(result.brief?.markdown.contains("[Before]") == true)
    #expect(result.brief?.markdown.contains("[At]") == false)
}

@Test func ongoingEventsAndMarkdownEvidenceArePreserved() throws {
    let zone = TimeZone(identifier: "Europe/Berlin")!
    let now = try Date.ISO8601FormatStyle().parse("2026-09-09T08:00:00Z")
    let start = try Date.ISO8601FormatStyle().parse("2026-09-08T20:00:00Z")
    let end = try Date.ISO8601FormatStyle().parse("2026-09-09T01:00:00Z")
    let adapter = ControlledAdapter(report: SourceReport(
        status: SourceStatus(source: .calendar, state: .available, refreshedAt: now),
        observations: [SourceObservation(
            title: "Plan [A]\\B\r\nNow",
            startsAt: start,
            endsAt: end,
            evidenceLink: URL(string: "eventkit://event/a(b)")!
        )]
    ))

    let result = ApplicationCore(adapter: adapter, store: ControlledStore()).run(now: now, timeZone: zone)

    #expect(result.brief?.markdown.contains("[Plan \\[A\\]\\\\B Now](<eventkit://event/a(b)>)") == true)
}

@Test func unavailableCalendarDoesNotComplete() {
    let status = SourceStatus(source: .calendar, state: .denied, refreshedAt: nil)
    let adapter = ControlledAdapter(report: SourceReport(status: status, observations: []))
    let store = ControlledStore()

    let result = ApplicationCore(adapter: adapter, store: store).run()

    #expect(result == BriefRunResult(outcome: .notCompleted, brief: nil, statuses: [status]))
    #expect(store.saved == nil)
}

@Test func existingBriefIsRetrieved() {
    let day = BriefDay(now: .now, timeZone: .current)
    let brief = CanonicalBrief(day: day, markdown: "existing")
    let adapter = ControlledAdapter(report: SourceReport(
        status: SourceStatus(source: .calendar, state: .failed, refreshedAt: nil),
        observations: []
    ))
    let store = ControlledStore(existing: brief)

    let result = ApplicationCore(adapter: adapter, store: store).run()

    #expect(result == BriefRunResult(
        outcome: .retrieved,
        brief: brief,
        statuses: [SourceStatus(source: .calendar, state: .failed, refreshedAt: nil)]
    ))
}

private final class ControlledAdapter: SourceAdapter {
    let report: SourceReport

    init(report: SourceReport) { self.report = report }
    func observations(in window: DateInterval) -> SourceReport { report }
}

private final class ControlledStore: BriefStore {
    let existing: CanonicalBrief?
    var saved: CanonicalBrief?

    init(existing: CanonicalBrief? = nil) { self.existing = existing }

    func brief(for day: BriefDay) -> CanonicalBrief? { existing }
    func save(_ brief: CanonicalBrief) { saved = brief }
}

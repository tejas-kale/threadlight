import EventKit
import Foundation

public final class EventKitCalendarAdapter: SourceAdapter {
    private let selectedCalendarIdentifiers: Set<String>
    private let store = EKEventStore()

    public init(selectedCalendars: [String]) {
        selectedCalendarIdentifiers = Set(selectedCalendars)
    }

    public func calendars() -> [(title: String, identifier: String)]? {
        guard requestAccess() else { return nil }
        return store.calendars(for: .event).map { ($0.title, $0.calendarIdentifier) }.sorted {
            ($0.title, $0.identifier) < ($1.title, $1.identifier)
        }
    }

    public func observations(in window: DateInterval) -> SourceReport {
        guard requestAccess() else {
            return SourceReport(
                status: SourceStatus(source: .calendar, state: .denied, refreshedAt: nil),
                observations: []
            )
        }
        let calendars = store.calendars(for: .event).filter {
            selectedCalendarIdentifiers.contains($0.calendarIdentifier)
        }
        guard calendars.count == selectedCalendarIdentifiers.count else {
            return SourceReport(
                status: SourceStatus(source: .calendar, state: .failed, refreshedAt: nil),
                observations: []
            )
        }
        let events = store.events(matching: store.predicateForEvents(
            withStart: window.start,
            end: window.end,
            calendars: calendars
        ))
        let observations = events.compactMap { event -> SourceObservation? in
            guard let identifier = event.eventIdentifier,
                  let encoded = identifier.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let link = URL(string: "eventkit://event/\(encoded)") else { return nil }
            return SourceObservation(
                title: event.title ?? "Untitled",
                startsAt: event.startDate,
                endsAt: event.endDate,
                evidenceLink: link
            )
        }
        return SourceReport(
            status: SourceStatus(source: .calendar, state: .available, refreshedAt: .now),
            observations: observations
        )
    }

    private func requestAccess() -> Bool {
        if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
            let finished = DispatchSemaphore(value: 0)
            store.requestFullAccessToEvents { _, _ in finished.signal() }
            finished.wait()
        }
        let status = EKEventStore.authorizationStatus(for: .event)
        return status == .fullAccess
    }
}

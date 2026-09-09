import Foundation
import ThreadlightCore

let arguments = Array(CommandLine.arguments.dropFirst())
let selectedCalendarIdentifiers = arguments.indices.compactMap { index in
    arguments[index] == "--calendar" && index + 1 < arguments.count ? arguments[index + 1] : nil
}
let adapter = EventKitCalendarAdapter(selectedCalendars: selectedCalendarIdentifiers)

if arguments == ["--list-calendars"] {
    if let calendars = adapter.calendars() {
        calendars.forEach { print("\($0.title)\t\($0.identifier)") }
    } else {
        fputs("Calendar access was denied.\n", stderr)
        exit(1)
    }
} else if selectedCalendarIdentifiers.isEmpty {
    fputs("Usage: threadlight --list-calendars | --calendar ID [--calendar ID ...]\n", stderr)
    exit(2)
} else {
    let result = ApplicationCore(adapter: adapter, store: MemoryBriefStore()).run()
    print("Outcome: \(result.outcome.rawValue)")
    if let markdown = result.brief?.markdown {
        print(markdown)
    } else {
        for status in result.statuses {
            let refreshed = status.refreshedAt?.formatted(.iso8601) ?? "unknown"
            print("\(status.source.rawValue): \(status.state.rawValue); refreshed: \(refreshed)")
        }
        exit(1)
    }
}

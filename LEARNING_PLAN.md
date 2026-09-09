# Calendar brief learning plan

## Principal concepts

1. **Swift value types and protocols** — trace `BriefDay`, `BriefRunResult`, `SourceAdapter`, and `BriefStore` in `ThreadlightCore.swift`. Explain why controlled implementations can replace the real boundaries without changing `ApplicationCore`.
2. **Time zones and `Calendar` arithmetic** — work through how one instant becomes a Brief Day and why adding a day before setting 10:00 handles daylight-saving changes.
3. **EventKit permissions and queries** — inspect `EKEventStore` authorisation, selected `EKCalendar` values, `predicateForEvents`, and the translation from `EKEvent` to `SourceObservation`.
4. **Swift Package Manager** — identify the library, executable, and test targets and how the CLI depends on the platform-shared core.

Primary references are the Swift and EventKit documentation linked from `RESOURCES.md`.

## Retrieval exercise

Without opening the code, write down the three `BriefRunOutcome` cases, the Calendar window’s start and end, and the information retained by a `SourceObservation`. Then verify each answer in the source.

## Isolated exercise

In a Swift scratch package, construct `2026-03-28 12:00` in `Europe/Berlin`. Calculate the next day at 10:00 by calendar components, print both instants as ISO 8601, and explain the elapsed duration across the daylight-saving transition.

## Guided production validation

1. Run `swift test` and `swift build`.
2. Run `swift run threadlight --list-calendars`; approve Calendar access and note the identifier of one safe Calendar.
3. Add an event today and another tomorrow before 10:00 to that Calendar. Add one tomorrow after 10:00 as a counterexample.
4. Run `swift run threadlight --calendar "Calendar identifier"`.
5. Confirm both in-window events appear, the counterexample does not, each item has an `eventkit://` Evidence Link, and Calendar status and freshness are printed.
6. Deny Calendar access in System Settings, rerun, and confirm the result says `Calendar: denied` rather than printing an empty completed brief. Restore access afterwards.

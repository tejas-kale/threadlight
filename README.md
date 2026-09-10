# Threadlight

Threadlight is a private, Apple-first daily brief and, later, local knowledge
assistant. The project is also a practical route for an experienced Python
developer to learn native macOS and iOS development by building the production
code personally.

Planning is tracked in GitHub issues using a Wayfinder decision map. Routine
operation must remain on-device, apart from retrieving source data from its
existing provider and synchronising private app state through iCloud.

## Calendar CLI

```sh
swift test
swift build
swift run threadlight --list-calendars
swift run threadlight --calendar "CALENDAR-ID" --calendar "ANOTHER-ID"
```

The first EventKit command asks for Calendar access and prints titles with their
identifiers. Calendar selection applies to that run. Beginner lessons live in
`teach/`.

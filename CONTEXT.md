# Threadlight

Threadlight turns selected personal sources into one private daily orientation
while keeping provenance and partial failures visible.

## Language

**Brief Day**:
The calendar date, interpreted in the user's current time zone, for which one brief is produced.
_Avoid_: Report date, run date

**Brief Run**:
An attempt by one device to produce the Canonical Brief for a Brief Day.
_Avoid_: Refresh, report generation

**Canonical Brief**:
The first successfully completed brief for a Brief Day, shared between the user's devices.
_Avoid_: Latest brief, final report

**Source**:
A user-approved body of personal information from which Threadlight may construct a brief, such as selected Gmail labels, Reminder lists, or Calendars.
_Avoid_: Integration, database

**Source Observation**:
The bounded source material and freshness information considered during a Brief Run.
_Avoid_: Raw data, dump

**Evidence Link**:
A reference from a brief item back to the source item supporting it.
_Avoid_: Citation, URL

**Shadow Brief**:
A Canonical Brief produced during evaluation while the existing ChatGPT brief remains authoritative.
_Avoid_: Test brief, draft brief

**Cutover**:
The user's explicit decision to make Threadlight authoritative after shadow evaluation.
_Avoid_: Launch, automatic migration

# The smallest private iCloud brief contract

## Question

What is the smallest Apple-supported iCloud and CloudKit design that stores one
Markdown Canonical Brief with minimal evidence metadata per Brief Day and
prevents two devices from completing competing Brief Runs without introducing
unnecessary distributed-systems complexity?

## Decision

Use **one `CanonicalBrief` record per Brief Day in the user's CloudKit private
database**. Give it a deterministic record ID, use the same record first as a
short-lived generation claim and then as the completed brief, and save every
state transition with
`CKModifyRecordsOperation.RecordSavePolicy.ifServerRecordUnchanged`.

Do not use an iCloud Drive Markdown file as the lock or canonical store. Cache
the winning Markdown locally on each device for offline reading. A later
evaluation/export feature may materialise `.md` files, but those files should be
derived exports rather than a second source of truth.

This design is the minimum that provides server-arbitrated cross-device
exclusion. It needs one record type, one record per day, no custom record zone,
no separate lock record, no CloudKit subscription, and no merge algorithm.

## Why this is the smallest safe design

CloudKit gives each user a private database which, by default, only that user
can access. The data is not visible in the developer portal and counts towards
the user's iCloud quota. Both Threadlight targets can use the same container
when their entitlements grant access to it. Private-database access requires an
available iCloud account, so Threadlight must treat CloudKit availability as a
precondition for starting a Brief Run, not as an eventually-synchronised
afterthought. [Apple: `privateCloudDatabase`](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase)
[Apple: `CKContainer`](https://developer.apple.com/documentation/cloudkit/ckcontainer)

A caller may choose a `CKRecord.ID`; its record name is unique within a zone,
and CloudKit validates the uniqueness of a new record on save. With the default
`ifServerRecordUnchanged` save policy, CloudKit reports an error rather than
overwriting an existing record. Consequently, both devices can derive the same
record ID for a Brief Day and let CloudKit accept only one create. This is the
critical compare-and-swap operation for the initial claim.
[Apple: `CKRecord.ID`](https://developer.apple.com/documentation/cloudkit/ckrecord/id)
[Apple: `recordID`](https://developer.apple.com/documentation/cloudkit/ckrecord/recordid)

The same save policy also checks the server-maintained record change tag during
updates. If another device has saved a newer version, the stale save fails with
`serverRecordChanged`. This makes both claim takeover and completion
conditional on the caller still owning the latest record version.
[Apple: `ifServerRecordUnchanged`](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/recordsavepolicy/ifserverrecordunchanged)
[Apple: `serverRecordChanged`](https://developer.apple.com/documentation/cloudkit/ckerror/serverrecordchanged)

One record is preferable to separate lock and payload records. CloudKit can
modify several records atomically only where the record zone supports that
capability; keeping state and payload in one record avoids needing a
multi-record transaction at all. [Apple: atomic record-zone capability](https://developer.apple.com/documentation/cloudkit/ckrecordzone/capabilities-swift.struct/atomic)

## Record contract

Use the default zone in the private database and one record type:

```text
Record type: CanonicalBrief
Record ID:   brief-v1-<YYYY-MM-DD>-europe-berlin

Plain coordination fields
  schemaVersion: Int64
  state:         String       // "generating" or "complete"

Encrypted fields
  claimantID:    String       // random installation identifier, not hardware ID
  leaseUntil:    Date
  generatedAt:   Date?        // present only when complete
  evidence:      Data?        // versioned JSON, present only when complete

Automatically encrypted asset
  markdown:      CKAsset?     // UTF-8 Markdown, present only when complete
```

The record name deliberately embeds the agreed Europe/Berlin Brief Day. It is
not encrypted, so it must contain no source content or personal identifier. If
the product later changes its Brief Day time-zone rule, that is a record-key
migration decision rather than a silent formatting change.

Put content-bearing metadata in `encryptedValues`. Apple says encrypted fields
are encrypted on-device before upload and decrypted after fetch; `CKAsset` is
encrypted automatically. With Advanced Data Protection enabled, the encryption
keys are exclusively available to the owner (and any participants if the user
shares a record). Encrypted fields cannot be indexed, which is harmless here
because Threadlight fetches by deterministic record ID rather than querying
their contents. [Apple: Encrypting User Data](https://developer.apple.com/documentation/cloudkit/encrypting-user-data)
[Apple: `encryptedValues`](https://developer.apple.com/documentation/cloudkit/ckrecord/encryptedvalues)

Use a `CKAsset` for the Markdown because it preserves a file-shaped payload and
keeps growth out of ordinary record fields. CloudKit stores an asset separately
but saves it with its record. It stores the bytes, not the filename, so record
metadata or the deterministic ID must supply the export filename. A fetched
asset URL points into a staging area that the system may clear; move or copy it
into the app's local container before treating it as an offline cache.
[Apple: `CKAsset`](https://developer.apple.com/documentation/cloudkit/ckasset)

The `evidence` JSON should contain only what the rendered brief needs for audit
and later evaluation:

```text
schemaVersion
sourceObservations[]:
  sourceKind              // gmail, reminders, calendar
  fetchedAt
  windowStart/windowEnd
  outcome                 // succeeded or a non-sensitive failure category
evidenceItems[]:
  sourceKind
  sourceItemID            // provider-stable opaque identifier
  title                   // subject, reminder title, or event title
  relevantAt              // message date, due date, or event start
  evidenceLink
  briefSection
  shortSummary?           // no full body and no attachment
```

This retains provenance and partial-failure facts without preserving complete
messages, reminder notes, event notes, or attachments. The Markdown itself may
still contain personal information, so both payloads require the same privacy
treatment.

## State transitions

Use a fixed, deliberately generous lease (for example, 15 minutes) and no
heartbeat in v1.

1. **Look up today.** Derive the record ID and fetch it directly.
2. **Already complete.** Cache/display its Markdown and do not start another
   Brief Run.
3. **No record.** Create `state = generating`, a random `claimantID`, and
   `leaseUntil`, using `ifServerRecordUnchanged`. Only start source retrieval
   and generation after CloudKit confirms the save.
4. **Unexpired claim.** Do not generate. Poll only while the screen is active,
   or offer a manual “Check again” action.
5. **Expired claim.** Fetch the record, replace the claimant and lease, and save
   with `ifServerRecordUnchanged`. Start only after that conditional save wins.
6. **Complete.** The claimant updates the exact server-version record returned
   by its successful claim, setting `state = complete`, `generatedAt`,
   `evidence`, and `markdown`, again with `ifServerRecordUnchanged`.
7. **Lost race.** On `serverRecordChanged`, discard the local result, fetch the
   server record, and either display the winner or wait for its active claim.
   Never merge two generated briefs and never retry completion as an overwrite.

If generation fails cleanly, the owner may conditionally shorten the lease so
another manual attempt can claim sooner. If the app crashes, the fixed expiry
provides recovery without a separate failure record. Clock skew can make
takeover early or late, but it cannot create two canonical completions because
the record change tag still arbitrates every transition.

CloudKit network, authentication, quota, and service failures must leave the
Brief Day ungenerated. Apple documents distinct account states and retry hints;
Threadlight should surface these rather than falling back to an offline write.
This restriction is acceptable for the planned Gmail-backed brief because fresh
Gmail retrieval also requires a network connection. The last locally cached
Canonical Brief remains readable offline.
[Apple: `CKAccountStatus`](https://developer.apple.com/documentation/cloudkit/ckaccountstatus)
[Apple: `CKError`](https://developer.apple.com/documentation/cloudkit/ckerror)

## Why not coordinate with iCloud Drive?

An app can obtain an entitled ubiquity-container URL and place files there, but
iCloud documents are synchronised files, not a cross-device compare-and-swap
primitive. Apple explicitly documents simultaneous edits and offline edits
producing conflicting file versions; the app must detect and resolve them.
`NSFileCoordinator` coordinates access between local presenters and the local
iCloud machinery, but it does not prevent two disconnected devices from each
creating a candidate winner. Using a `.md` file as the claim would therefore
reintroduce precisely the conflict-resolution logic this contract avoids.
[Apple: ubiquity-container URL](https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:))
[Apple: Designing for Documents in iCloud](https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/DesigningForDocumentsIniCloud.html)
[Apple: `NSFileVersion.isConflict`](https://developer.apple.com/documentation/foundation/nsfileversion/isconflict)

For later LLM-as-judge evaluation, add an explicit export that writes completed
records as deterministic `.md` files, ideally accompanied by redacted or
synthetic evaluation metadata. That export must not participate in generation
coordination. Sending personal briefs to an external judge is also a separate
privacy decision, not implied by storing them privately in iCloud.

## Boundaries and follow-up validation

- No automatic regeneration exists in v1. A completed record is immutable from
  the app's normal flow.
- No background guarantee is implied. Both targets may check the deterministic
  record on launch or foreground activation; push subscriptions can wait until
  a demonstrated need.
- Do not use `changedKeys` or `allKeys` for these transitions: either can
  overwrite a winner. Always request `ifServerRecordUnchanged` explicitly even
  though Apple currently documents it as the default.
- Before relying on the contract, run a two-device prototype that races initial
  creation, races an expired-lease takeover against late completion, and tests
  network loss after CloudKit accepts a save but before the client receives its
  response. The last case is resolved by refetching the deterministic record,
  never by assuming failure or force-writing.
- Test with the CloudKit production environment before release. Apple notes
  that production rejects undeployed schema additions and that simulator uses
  only the development environment. [Apple: Enabling CloudKit in Your App](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app)
- Provide a user-visible export path. Apple states that data stored on a user's
  behalf belongs to the user and CloudKit apps need a way for users to view and
  export it. [Apple: Providing User Access to CloudKit Data](https://developer.apple.com/documentation/cloudkit/providing-user-access-to-cloudkit-data)

## Result

The decision is therefore **CloudKit-private, one deterministic record, two
states, conditional saves, fixed lease, local cache**. iCloud Drive Markdown is
an optional derived export. This gives Mac and iPhone a shared Canonical Brief
without two connectors having to agree through file-conflict resolution or a
bespoke distributed lock service.

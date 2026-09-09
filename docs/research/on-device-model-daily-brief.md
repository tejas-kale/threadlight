# Apple’s on-device model for Threadlight’s daily brief

## Decision

Use Apple’s on-device `SystemLanguageModel` for **bounded semantic work** in Threadlight: classify mail, produce short source-grounded summaries, identify possible follow-ups, propose a priority from an app-supplied candidate list, and return those judgements as a typed intermediate result.

Do not make the model responsible for facts or control flow that Swift can determine exactly. Source retrieval, date windows, overdue/due status, calendar ordering and collisions, counts, links, source freshness, failure reporting, the canonical Brief Day, and final Markdown structure should remain deterministic.

This is an architecture decision, not yet a quality claim. Apple describes prompt outputs as variable and recommends systematic evaluation. Threadlight therefore needs a small device-specific prototype and evaluation set before the model is accepted for daily use. The intended devices are eligible for Apple Intelligence, but the MacBook Air M1 may run a different-capability on-device model from the iPhone Air under macOS/iOS 27, so both must pass the same evaluations independently.

## Why the model fits the semantic portion

Apple presents the on-device model as suitable for summarising, analysing, classifying or judging text, and generating tags. It explicitly lists text classification and tagging among supported task shapes, while warning that the model is not appropriate for basic arithmetic or logical reasoning. That division maps cleanly to Threadlight: meaning-dependent judgements belong to the model; arithmetic, scheduling and bookkeeping belong to code. [Generating content and performing tasks with Foundation Models](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models)

For mail triage, use either the general model with a small closed category enum or evaluate Apple’s specialised content-tagging use case. The specialised model identifies topics, actions, objects and emotions, supports `Generable`, and allows maximum tag counts. Apple also warns that reused sessions can blend previous turns and that duplicate tags can occur, so Threadlight should use fresh, bounded sessions for independent items or batches and deduplicate results in code. [Categorizing and organizing data with content tags](https://developer.apple.com/documentation/foundationmodels/categorizing-and-organizing-data-with-content-tags)

Guided generation is appropriate for the intermediate result. `@Generable` and `@Guide` use constrained sampling to guarantee that output conforms to a Swift structure; enums can restrict classifications to values such as `needsAttention`, `worthKnowing`, and `lowPriority`. This removes fragile JSON parsing, but it guarantees **shape**, not truth or good judgement. Threadlight must still validate every returned source identifier and test semantic quality. [Generating Swift data structures with guided generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation)

The framework runs the model on-device, keeps model inputs and outputs on-device, works offline, and does not require an account, API key, or per-request charge. This satisfies Threadlight’s default inference privacy requirement; it does not change the separate fact that Gmail retrieval itself uses Google’s service. [Meet the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2025/286/)

## Recommended allocation of responsibilities

| Brief responsibility | Owner | Reason |
|---|---|---|
| Fetch selected Gmail labels, Reminder lists and Calendars | Deterministic app code | Permissions, selection and source errors must be exact and auditable. |
| Apply the preceding-24-hours, today, overdue and next-morning windows | Deterministic app code | Date and time-zone logic is not a language task. |
| Determine event ordering and collisions | Deterministic app code | Apple warns against using the model for maths and logical reasoning. |
| Count low-priority messages and group known sender/category rules | Deterministic app code where rules exist | Counts and stable rules should be repeatable. |
| Classify ambiguous mail | On-device model | This is a supported classify/judge task shape. |
| Write short, source-grounded mail summaries | On-device model | Summarisation is a supported model task. |
| Detect possible waiting/follow-up conversations | On-device model, marked as a suggestion | This requires semantic interpretation and can be wrong; retain evidence and evaluate recall. |
| Choose a recommended priority | Hybrid | Code supplies valid candidates and hard constraints; the model selects an identifier and gives a short rationale; code rejects unknown identifiers. |
| Render headings, counts, links, freshness and failure notices | Deterministic app code | The brief’s contract must survive prompt and model changes. |
| Prevent a second successful Brief Run for the Brief Day | Deterministic persistence/synchronisation | This is application state, never a model decision. |

The intermediate generated type should contain only bounded fields: a validated source ID, a closed category, a short summary, an optional follow-up flag and reason, plus a selected priority candidate ID and rationale. The renderer should join those IDs back to canonical source metadata rather than asking the model to reproduce senders, dates, URLs or counts.

## Constraints the design must accommodate

### Availability is conditional

The app must check `SystemLanguageModel.availability` at runtime. Even on eligible hardware, the model can be unavailable because Apple Intelligence is disabled or the model is not ready, for example while assets are downloading. The interface needs a clear unavailable/retry state rather than silently omitting analysis. [Apple’s Foundation Models sample](https://developer.apple.com/documentation/foundationmodels/adding-intelligent-app-features-with-generative-models)

Apple lists the iPhone Air and MacBook Air M1 and later as Apple Intelligence-compatible. However, for the 2027 OS release Apple says its most powerful on-device model requires an iPhone Air (or iPhone 17 Pro family) or a Mac with M3 or later and at least 12 GB unified memory. This implies that hardware can affect the available model; it does **not** make the M1 unsuitable, but it makes cross-device evaluation mandatory. [Apple Intelligence compatibility](https://www.apple.com/apple-intelligence/), [Apple’s iOS/macOS 27 announcement](https://www.apple.com/newsroom/2026/06/apple-introduces-siri-ai-a-profoundly-more-capable-and-personal-assistant/)

### Context is scarce and device-dependent

Apple documents a 4,096-token context for the original on-device system model. Instructions, prompts, tool definitions, generated schemas, inputs and outputs all consume that budget. Apple added `contextSize` and token-counting APIs and advises adapting to the hardware’s model. Threadlight should query the actual context size, budget before generation, process mail in small independent batches, and reduce batch summaries deterministically or in a final bounded synthesis session. It should never feed the entire preceding day’s mail bodies into one session. [Managing the context window](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window), [What’s new in the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2026/241/)

A practical first pipeline is:

1. Code retrieves and normalises each permitted source item.
2. Code discards quoted history, signatures and irrelevant headers where this can be done safely.
3. Fresh sessions classify and summarise small mail batches into typed records.
4. Code validates identifiers, removes duplicates, calculates exact sections and counts, and constructs the priority candidate list.
5. One bounded model call selects a candidate and writes its rationale.
6. Code renders the stable Markdown template and records any source or model failure explicitly.

### Failures are part of normal operation

The framework exposes errors for an exceeded context, rate limiting, refusal, timeout, guardrail violations, unsupported capabilities, unsupported transcript content, unsupported generation guides, and unsupported language or locale. A `LanguageModelSession` also permits only one request at a time. Threadlight should serialise requests per session, apply bounded retries only to transient failures, and produce a partial brief with an exact model-status notice when semantic analysis cannot complete. [LanguageModelError](https://developer.apple.com/documentation/foundationmodels/languagemodelerror), [LanguageModelSession.Error.concurrentRequests](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/error/concurrentrequests)

Incoming mail is untrusted prompt content. Apple says unverified input must not be placed in session instructions because that increases prompt-injection risk; trusted behavioural rules belong in `Instructions`, while mail content belongs in the prompt as clearly delimited data. Output must remain schema-constrained and incapable of invoking mutating actions. [Improving the safety of generative model output](https://developer.apple.com/documentation/FoundationModels/improving-the-safety-of-generative-model-output)

Language support must also be checked at runtime with `supportsLocale(_:)`. Calls can fail with `unsupportedLanguageOrLocale`, and Apple warns that safety guardrails are designed only for supported languages. Threadlight should initially generate British English, record unsupported-language failures, and avoid pretending an unanalysed message was low priority. [Supporting languages and locales with Foundation Models](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)

### Model updates can change behaviour

Apple advises recording outputs from the previous model, comparing them with the new version, and versioning prompts when behaviour changes. Threadlight should version each prompt/schema pair in the Brief Run metadata and rerun its evaluation set after OS/model updates. Hard-coded prompts are acceptable for the personal v1, provided updating the app is understood to be the deployment mechanism. [Updating prompts for new model versions](https://developer.apple.com/documentation/foundationmodels/updating-prompts-for-new-model-versions)

Greedy sampling can make a given input produce the same output for a given model, and is a sensible v1 default for triage and prioritisation. It does not protect against behaviour changes when the underlying model or prompt changes, nor does repeatability prove correctness. [GenerationOptions.SamplingMode.greedy](https://developer.apple.com/documentation/foundationmodels/generationoptions/samplingmode-swift.struct/greedy)

## Acceptance gate before relying on the model

Build the Mac vertical slice first, but evaluate the same prompt/schema pipeline on both the MacBook Air M1 and iPhone Air before claiming independent cross-device generation works. Keep ChatGPT as the operational brief during the shadow period.

Start with invented fixtures and a small local, git-ignored set derived from real briefs. Score at least:

- critical-item recall, with zero tolerance for a missed known-critical item;
- unsupported claims, with zero tolerance;
- correct source-ID attachment and working evidence links;
- category agreement against Tejas’s judgement;
- follow-up recall and false-positive rate;
- priority candidate validity and usefulness;
- correct partial-failure wording; and
- latency and completion rate on each target device.

Apple’s Evaluations framework can run datasets, apply rule-based or model-based metrics and aggregate results. Apple specifically recommends aligning any model judge with human judgement before relying on it. That supports the proposed later LLM-as-judge experiment, but deterministic checks and Tejas’s review should remain authoritative for factuality and cutover. [Evaluating prompts to measure performance and improve model responses](https://developer.apple.com/documentation/foundationmodels/evaluating-prompts-to-measure-performance-and-improve-model-responses), [Evaluations framework](https://developer.apple.com/documentation/evaluations)

## Consequences for the plan

- Keep `SystemLanguageModel` as Threadlight’s default and only routine brief-generation model; leave PCC disabled and outside the v1 path.
- Prototype one end-to-end semantic slice early: several sanitised mail records in, typed classifications and summaries out, deterministic Markdown rendered.
- Do not postpone deterministic source normalisation and evidence IDs; they are what make model output auditable.
- Treat follow-up detection and priority selection as evaluated suggestions, never silent facts.
- Budget and batch dynamically using `contextSize` and token counting rather than relying on one fixed limit.
- Version prompts and schemas, retain the model/prompt version in each Brief Run, and rerun evaluations after OS updates.
- Preserve a complete non-generative failure path that still shows exact Reminders, Calendar events, source freshness and why mail analysis is missing.

## Remaining uncertainty

Apple’s documentation establishes capability and constraints, not Threadlight-specific accuracy. The research cannot establish whether the M1 and iPhone Air models meet the proposed quality bar, how much mail fits after normalisation, or acceptable latency. Those questions require the planned prototype and measurements on the actual devices.

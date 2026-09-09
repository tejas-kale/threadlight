# Apple HIG: Threadlight’s first macOS window

Research date: 9 September 2026. Sources below are Apple’s current Human
Interface Guidelines and SwiftUI documentation.

## Recommended first-window shape

Use a two-column `NavigationSplitView`: a leading sidebar for stable,
top-level destinations (for example, **Brief Day** and **Sources**) and a
content pane that shows the selected destination’s working content. This fits
Apple’s split-view pattern: a sidebar navigates top-level collections and the
secondary pane shows their contents. Keep the sidebar flat or at most two
levels deep, retain its selection, and make it hideable (but visible by
default). Do not turn the sidebar into a duplicate summary of the selected
brief; it is navigation, not a second copy of the content.

For the initial app, show the most pertinent detail on launch: today’s Brief
Day, or a useful empty state when no Sources are authorised. This follows the
HIG’s direction to show the most relevant detail at launch and to give
essential information sufficient space.

Sources:

- [Split views — Apple HIG](https://developer.apple.com/design/human-interface-guidelines/split-views)
- [Sidebars — Apple HIG](https://developer.apple.com/design/human-interface-guidelines/sidebars)
- [Layout — Apple HIG](https://developer.apple.com/design/human-interface-guidelines/layout)

## Accounts and Sources

Treat account-level preferences and rarely changed defaults as Settings:
for example, an account identity, default Brief Day behaviour, or an overall
privacy preference. On macOS, expose Settings through the app menu
(`Command`-`,`), not a toolbar button. If Settings has panes, use its stable,
noncustomisable toolbar and restore the last pane.

Do **not** make Settings the only route for the core act of authorising,
inspecting, repairing, or removing a Source. Source approval is meaningful
product work with immediate consequences for the daily brief; expose a
**Sources** destination and give it an empty state with an explicit “Add
Source” action. A Settings-linked source manager would be acceptable only if
Sources are genuinely infrequent, global configuration. This distinction is an
application of Apple’s guidance to put general, infrequently changed options
in Settings and not use Settings for setup information available in context.

Avoid duplicate controls and state. If Sources is a main destination, Settings
should link there or contain only source-wide defaults — not a second editable
source list. Likewise, do not duplicate system-wide settings such as
authentication and accessibility options.

Source:

- [Settings — Apple HIG](https://developer.apple.com/design/human-interface-guidelines/settings)

## Toolbar and primary work

Reserve the window toolbar for frequent, contextual commands rather than
configuration. Keep it sparse, group related controls, and ensure every
toolbar command also exists in the menu bar because macOS users can hide or
customise toolbars.

When the selected view has one clearly primary frequent command — initially
likely **Add Source** in the Sources empty state, later perhaps **Run Brief**
only if it is a deliberate user command — make it the sole primary action.
For SwiftUI on macOS, use `ToolbarItemPlacement.primaryAction`; Apple places
that placement at the **leading** edge on macOS. This platform-specific API
guidance takes precedence over copying iOS trailing-button conventions. Put
navigation (including sidebar visibility) at the leading edge in its familiar
position; keep secondary or less-frequent actions in a menu/overflow.

Sources:

- [Toolbars — Apple HIG](https://developer.apple.com/design/human-interface-guidelines/toolbars)
- [SwiftUI `ToolbarItemPlacement.primaryAction`](https://developer.apple.com/documentation/swiftui/toolbaritemplacement/primaryaction)
- [SwiftUI `ToolbarItemPlacement.navigation`](https://developer.apple.com/documentation/swiftui/toolbaritemplacement/navigation)

## Status, partial failure, and errors

Keep nonurgent Source freshness, availability, and Brief Run status close to
the item it describes — for example, an unobtrusive status line or badge in a
Source row and clear incomplete-source context in the brief. The feedback
should say what cannot happen and why, and offer a relevant repair action
(such as reconnecting a Source). This preserves Threadlight’s requirement to
make provenance and partial failures visible without forcing people away from
their work.

Use a modal alert only for a critical, actionable interruption or a
non-undoable destructive consequence. Do not present an alert at launch for a
routine issue such as an unavailable account: show cached or placeholder
content plus a discoverable, nonintrusive explanation instead. Alert titles
must describe the specific situation rather than say merely “Error”; use
concrete verb-based button labels and include Cancel for an unexpected
destructive action.

Sources:

- [Feedback — Apple HIG](https://developer.apple.com/design/human-interface-guidelines/feedback)
- [Alerts — Apple HIG](https://developer.apple.com/design/human-interface-guidelines/alerts)

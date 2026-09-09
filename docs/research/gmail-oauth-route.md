# Gmail OAuth route for Threadlight

Research date: 9 September 2026

## Decision

For Threadlight's personal-use macOS and iOS apps:

1. Use one Google Cloud project with the Gmail API enabled.
2. Register a separate native OAuth client for each Apple platform target. Google's current Google Sign-In setup guide requires the **iOS** application type for both iOS and macOS, while Google's OAuth policy requires a separate client per platform. Associate each client with that target's bundle identifier.
3. Integrate Google's maintained `GoogleSignIn` Swift package rather than implementing the OAuth protocol directly. Use its system-browser flow, per-target reversed-client-ID callback scheme, sign-in restoration and token refresh APIs.
4. Request only `https://www.googleapis.com/auth/gmail.readonly`, and request it when the user enables Gmail rather than at basic sign-in. Do not request `gmail.modify`, `mail.google.com`, a server client ID, or backend access.
5. Keep the OAuth audience **External**. Use **Testing** only during the earliest development work, then change the publishing status to **In production** for normal personal use. Do not submit for verification while Threadlight remains a personal app used by fewer than 100 people; accept the unverified-app warning during authorisation and the 100-new-user cap.
6. Let Google Sign-In persist each device's authorisation in that device's Keychain. Do not synchronise tokens through iCloud and do not save them in app files, `UserDefaults`, logs, fixtures, or the repository.
7. Treat reauthorisation as a normal state. A failed token refresh must move the Gmail source to a visible “sign in again” state without preventing Calendar and Reminders from producing a partial brief.

This is the least-privilege route that can still read message bodies for local summarisation. It deliberately optimises for one person's sideloaded app. Public distribution would reopen verification, privacy-policy and restricted-scope security-assessment decisions.

## Why `gmail.readonly` is necessary

Google classifies both `gmail.readonly` and `gmail.metadata` as restricted scopes. `gmail.metadata` exposes labels and headers but not message bodies; Threadlight needs message content to distinguish “needs attention”, “worth knowing” and low-priority roll-ups. `gmail.readonly` is therefore the narrowest sufficient scope. It allows viewing messages and settings but not modifying mail. The broader `gmail.modify` and `mail.google.com` scopes would violate Threadlight's read-only requirement. [Google: Choose Gmail API scopes](https://developers.google.com/workspace/gmail/api/auth/scopes)

The scope should be requested only when Gmail is enabled. Google's native API-access guide supports checking `grantedScopes`, asking for an additional scope in response to a user interaction, and refreshing tokens before an API call. [Google: Access Google APIs in an iOS app](https://developers.google.com/identity/sign-in/ios/api-access)

## Audience, publishing status and verification

The project should use an External audience because a personal Gmail account is not an Internal Google Workspace organisation audience. Google explicitly exempts personal-use apps with fewer than 100 users from mandatory OAuth verification; users may proceed through the unverified-app warning. All apps must still comply with the Google API Services User Data Policy. [Google: When verification is not needed](https://support.google.com/cloud/answer/13464323)

Testing status is unsuitable once Threadlight is expected to run daily. For scopes beyond basic identity, a test user's authorisation expires seven days after consent, and an offline refresh token expires with it. In-production projects are available to Google Accounts; an unverified app requesting restricted scopes remains subject to the warning and a lifetime cap of 100 new users. [Google: Manage app audience](https://support.google.com/cloud/answer/15549945)

Therefore:

- use Testing while the sign-in screen is under active construction;
- before expecting durable daily operation, set the app to In production;
- keep the app unverified under the documented personal-use exemption while it remains personal;
- revisit the entire decision before sharing it beyond a small personal-use group.

If Threadlight becomes a public user-facing product, `gmail.readonly` requires restricted-scope verification. Google's published requirements also attach an annual security assessment to restricted-scope apps. [Google: Verification requirements](https://support.google.com/cloud/answer/13464321) This future cost is a reason to preserve a narrow connector boundary, not a reason to request an insufficient scope now.

## Native clients and redirects

Google's current Apple-platform guide says that iOS and macOS apps using Google Sign-In must configure an OAuth client whose application type is iOS, and that the Xcode project must contain the client ID and a custom URL scheme formed from the reversed client ID. It also requires Apple code signing for Keychain credential storage and a Keychain access group on macOS. [Google: Get started with Google Sign-In for iOS and macOS](https://developers.google.com/identity/sign-in/ios/start-integrating)

Google's OAuth policy says to register a separate OAuth client for each platform. Threadlight should consequently use two clients in the same Cloud project—one bound to the macOS target and one bound to the iOS target—even though both have the “iOS” client type in Google's console. [Google: OAuth 2.0 policies](https://developers.google.com/identity/protocols/oauth2/policies)

The Google Sign-In SDK documents the platform-specific redirect plumbing: iOS passes the callback URL to `GIDSignIn.handle`, while macOS registers for the `kAEGetURL` Apple event and passes the event URL to the SDK. The SDK also exposes `restorePreviousSignIn` so launch does not require interactive consent each time. [Google: Integrating Google Sign-In into iOS or macOS](https://developers.google.com/identity/sign-in/ios/sign-in)

This SDK route is preferable to hand-rolled OAuth for a learning project. Google's installed-app protocol requires a system browser and supports PKCE; its lower-level loopback redirect is recommended for desktop apps but deprecated for iOS client types. The SDK avoids Threadlight having to own those protocol details and gives both Apple targets a consistent integration. [Google: OAuth 2.0 for iOS and desktop apps](https://developers.google.com/identity/protocols/oauth2/native-app)

## Tokens, Keychain and failure behaviour

Access tokens are short-lived; the app should call the SDK's `refreshTokensIfNeeded` before Gmail requests. At launch it should attempt `restorePreviousSignIn`, then inspect whether `gmail.readonly` remains granted. [Google: Access Google APIs in an iOS app](https://developers.google.com/identity/sign-in/ios/api-access)

Refresh tokens are not permanent. Google lists revocation, six months without use, a Google-password change when Gmail scopes are present, exceeding token limits and time-limited grants as reasons a refresh token can stop working. Threadlight must therefore model “authorisation expired” and offer an explicit sign-in repair path. [Google: Using OAuth 2.0 to access Google APIs](https://developers.google.com/identity/protocols/oauth2)

Use Google Sign-In's own persisted session rather than creating a second token store. If Threadlight ever owns a token directly, Apple's Keychain—not a preferences database or document—is the appropriate encrypted store for a small secret. [Apple: Keychain services](https://developer.apple.com/documentation/security/keychain-services/)

Each device should authorise independently with its platform client. Do not make the Keychain item synchronisable and do not copy a refresh token through Threadlight's iCloud container. The shared daily brief is application data; OAuth credentials are not.

## Client IDs and secrets

Threadlight has no backend in this design, so it does not need a web/server OAuth client ID, server authentication code, or client secret. Google's Apple integration guide describes the server client ID as optional and only needed for backend authentication. [Google: Get started with Google Sign-In for iOS and macOS](https://developers.google.com/identity/sign-in/ios/start-integrating)

Native client identifiers must be present in the shipped application and are not confidential in the way a server secret is. Nevertheless, Google's policy recommends avoiding committing OAuth client information to any repository. Keep downloaded credential files and per-target client-ID configuration in ignored local Xcode configuration files. Commit only documented placeholders and setup instructions. Never put a client secret in the app. [Google: OAuth 2.0 policies](https://developers.google.com/identity/protocols/oauth2/policies)

## Implementation acceptance checks

The later Gmail connector implementation should demonstrate that:

- consent requests exactly `gmail.readonly` and no write-capable Gmail scope;
- macOS and iOS use distinct native clients and callback schemes;
- quitting and relaunching restores sign-in without exposing tokens to files or logs;
- an expired or revoked grant becomes a recoverable source-level failure;
- Gmail failure still permits a clearly labelled partial brief from Calendar and Reminders;
- disconnecting revokes access and removes local credentials;
- no Gmail body, token or real-message fixture enters Git or iCloud as part of authentication.

## Boundary of this finding

This note establishes authentication and authorisation architecture. It does not decide Gmail message-query semantics, MIME parsing, local evidence retention, or how a daily brief arbitrates concurrent Mac and iPhone generation. Those belong to later decisions.

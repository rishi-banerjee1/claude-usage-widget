# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A macOS floating desktop widget that displays Claude API usage limits in real-time. Single-file Swift app — no Xcode project, no dependencies, no package manager. Compiles with `swiftc` directly against Cocoa, SwiftUI, and Security frameworks.

The widget is the sole UI — no menubar icon, no dock icon. It floats on the desktop across all Spaces using a borderless `NSPanel`. All interaction is via right-click context menu (Settings / Refresh / Quit).

## Build & Run

```bash
./build.sh                        # Compile + bundle into build/ClaudeUsage.app
open build/ClaudeUsage.app        # Launch (auto-shows widget)
killall ClaudeUsage               # Stop running instance
```

There are no tests, no linter, and no CI. The build is a single `swiftc` invocation:

```bash
swiftc ClaudeUsageApp.swift -o build/ClaudeUsage.app/Contents/MacOS/ClaudeUsage \
  -framework Cocoa -framework SwiftUI -framework Security -parse-as-library
```

After editing `ClaudeUsageApp.swift`, always rebuild and relaunch — there is no hot reload.

## Architecture

Everything lives in `ClaudeUsageApp.swift` (~1634 lines). Key sections in order:

1. **MetricType** — Enum defining available metrics (5-hour, 7-day, Sonnet) with display names and short labels
2. **LoginItemManager** — `SMAppService`-based Launch at Login (macOS 13+ native API, no special permissions required)
3. **UpdateChecker** — Fetches `VERSION` from GitHub raw, compares semver against local `CFBundleShortVersionString`, handles self-update via locked-down `Process` API (no shell)
4. **KeychainHelper** — Secure credential storage using macOS Keychain (`SecItemAdd`/`SecItemCopyMatching`/`SecItemDelete`)
5. **Preferences** — Singleton: session key in Keychain (with one-time migration from UserDefaults), other settings in `UserDefaults.standard`
6. **SettingsView** — SwiftUI view hosted in an `NSWindowController`, with credential hints inline and update banner. Session key uses `SecureField` (masked input)
7. **FloatingWidgetPanel** — `NSPanel` subclass: borderless, floating, non-activating, all Spaces, draggable
8. **WidgetState** — Enum: `.ok`, `.needsSetup`, `.sessionExpired`, `.loading`
9. **WidgetView** — SwiftUI view with four states + compact/full mode, circular progress ring, pace tracking, status messages, other-limits display, blue update dot, context menu (Compact/Full Size, Settings/Refresh/Quit)
10. **WidgetPanelController** — Manages panel lifecycle, saves/restores position via UserDefaults, compact toggle with animated panel resize. Stores `moveObserver` token and removes it in `deinit` to prevent observer accumulation.
11. **AppDelegate** — The core: 30-second fetch timer, 24-hour update check timer, HTTP requests, retry logic with jitter, Cloudflare cooldown, status calculation
12. **Data Models** — `UsageResponse` and `UsageLimit` (Codable, maps to Claude API JSON)
13. **Main Entry** — `@main` struct bootstraps `NSApplication` as `.accessory` (no dock icon)

## Key Patterns

- **SwiftUI inside Cocoa**: All SwiftUI views are wrapped in `NSHostingView` for embedding in `NSPanel`/`NSWindow`
- **Settings propagation**: Save button posts `Notification.Name.settingsChanged`, AppDelegate observes it to re-fetch and resets `isSessionExpired` flag
- **Keychain storage**: Session key stored in macOS Keychain using `SecAccessCreate` with a `nil` trusted-apps list (open ACL) — any process can read without a password prompt, preventing repeated keychain dialogs across rebuilds. One-time transparent migration from UserDefaults on first launch after upgrade.
- **Retry with jitter**: Failed API calls retry up to 3 times with exponential backoff + random jitter (`baseDelay * (0.5 + random(0...1.0))`) to avoid thundering herd
- **Cloudflare vs session expiry**: HTTP 401/403 responses are inspected — Cloudflare challenge pages (HTML with "Just a moment") trigger retry with backoff; real auth errors (JSON) trigger `.sessionExpired` widget state
- **Cloudflare cooldown**: After 3+ consecutive Cloudflare failures (all retries exhausted), polling pauses for 5 minutes. Counters reset on successful fetch or settings change.
- **Polling pause on expiry**: When session is confirmed expired (`isSessionExpired = true`), the 30-second timer skips API calls to avoid hammering the server. Resets when user saves new credentials via Settings.
- **Pace calculation**: `expectedUsage = (timeElapsed / windowDuration) * 100`, compared ±5% to determine on-track/borderline/exceeding
- **Multi-limit awareness**: Other limits are always visible at all utilization levels (e.g., "7d: 34%  sonnet: 11%"). When the selected metric hits 100% but others have room, the widget shows "Still usable" with a green badge. "All limits reached" only appears when everything ≥90%.
- **No-cache API requests**: `cachePolicy = .reloadIgnoringLocalCacheData` + `Cache-Control: no-cache` on every fetch — ensures limit changes from admin console are reflected immediately
- **Compact mode**: Double-click or right-click → "Compact" toggles between full (140x170) and compact (76x76). Compact view is frameless — just the progress ring floating on desktop. `.ultraThinMaterial` background fades in on hover via `@State isHovering` + `.onHover`. State persisted in `Preferences.compactMode`. Panel resizes with animation anchored to top-left corner.
- **Shell lockdown**: UpdateChecker uses `Process` API with explicit `executableURL` and `arguments` — no shell, no string interpolation. `runGitPull(in:)` and `runBuildScript(in:)` replace the old `runShell()` method.

## API

Single endpoint, polled every 30 seconds:

```
GET https://claude.ai/api/organizations/{orgId}/usage
Cookie: sessionKey={key}
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ClaudeUsageWidget/1.0
```

Returns JSON with optional fields: `five_hour`, `seven_day`, `seven_day_sonnet`, etc. Each has `utilization: Double` and `resets_at: String?` (ISO8601).

**Cloudflare note**: The API sits behind Cloudflare. `curl` requests may get challenged with a 403 HTML page ("Just a moment..."). The app's `URLSession` typically passes through. Both the app and `setup.sh` detect Cloudflare challenges by checking the response body for markers (`Just a moment`, `challenge-platform`, `_cf_chl_opt`, `cf-browser-verification`) and handle them as transient errors rather than session expiry.

## Credentials

- **Setup**: `./setup.sh` — interactive CLI that guides session key paste, auto-fetches org ID via API, validates, and saves
- **Session key**: User pastes from browser cookies. Expires periodically — app detects via 401/403, widget shows "Session Expired". Settings uses `SecureField` (masked input).
- **Org ID**: Auto-fetched by `setup.sh` via `GET /api/organizations`. Never expires.
- **Storage**: Session key in macOS Keychain (service: `com.claude.usage`, account: `sessionKey`, open ACL via `SecAccessCreate`). Org ID and other settings in `UserDefaults`. Falls back to env vars `CLAUDE_SESSION_KEY` and `CLAUDE_ORGANIZATION_ID`.
- **Migration**: On first launch after upgrade, session key is transparently migrated from UserDefaults to Keychain and deleted from UserDefaults.
- **Security**: `setup.sh` never reads browser files or cookies directly. Input is masked (`read -s`). No credentials in logs or temp files.

## File Roles

| File | Purpose |
|------|---------|
| `ClaudeUsageApp.swift` | Entire app source (~1610 lines) — edit this for all changes |
| `Info.plist` | Bundle config: `LSUIElement=true`, min macOS 13.0. Version is a placeholder (`0.0`) — overwritten at build time from `VERSION` file via `PlistBuddy` |
| `build.sh` | Build script: generates icon, copies plist, injects version from `VERSION` via `PlistBuddy`, compiles with `swiftc`, ad-hoc signs with `codesign` |
| `run.sh` | Kill existing + rebuild if needed + launch |
| `setup.sh` | Interactive credential setup — guides paste, auto-fetches org ID, validates, detects Cloudflare |
| `generate-icon.sh` | Programmatically draws app icon via inline Swift |
| `install.sh` | One-command installer — downloads latest release, installs to /Applications, launches |
| `create-dmg.sh` | Packages app into distributable DMG |
| `README.md` | User-facing documentation and troubleshooting |
| `DEVELOPMENT.md` | Developer guide — architecture, adding features, debugging |
| `CLAUDE.md` | Claude Code guidance — this file |
| `icon.svg` | Source icon for the app |
| `VERSION` | Version string for update checking — bumped only for material releases |
| `release.sh` | Release automation — build, package, SHA256, GitHub release, Homebrew update instructions |
| `record-demo.sh` | Records demo GIF via screencapture + ffmpeg |
| `assets/` | Widget screenshots and demo GIF for README |
| `docs/` | GitHub Pages landing page |

## Logging

App logs to `~/.claude-usage/app.log` (append) and keeps last 50 entries in memory. Viewable in Settings → Log tab.

## Common Gotchas

- `LSUIElement=true` means no dock icon — the app only shows the floating widget (no menubar icon either)
- `generate-icon.sh` uses inline Swift compilation via heredoc — it may fail on some setups but build.sh continues gracefully
- Widget position is saved per-pixel in UserDefaults — resetting preferences (`defaults delete com.claude.usage`) clears everything including credentials
- **Cloudflare 403 ≠ session expired**: `curl` tests against the API may return 403 with an HTML challenge page — this is Cloudflare blocking non-browser requests, not an expired session. The app distinguishes these by checking the response body for Cloudflare markers before declaring session expired.
- **Polling pauses on expiry**: Once `isSessionExpired` is set, the 30-second timer skips fetches. The flag resets when `Notification.Name.settingsChanged` fires (user saves new credentials).

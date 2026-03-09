# Security Policy

## Supported Versions

Only the latest release is actively maintained and receives security fixes.

| Version | Supported |
|---------|-----------|
| Latest  | ✅ |
| Older   | ❌ |

## Reporting a Vulnerability

**Please do not report security vulnerabilities in public GitHub Issues.**

Open a [**GitHub Security Advisory**](https://github.com/rishi-banerjee1/claude-usage-widget/security/advisories/new) instead. This keeps the details private until a fix is released.

Include as much of the following as possible:

- Description of the vulnerability and its potential impact
- Steps to reproduce
- Affected version(s)
- Any suggested mitigations (optional)

You'll receive a response acknowledging the report. A fix will be prioritised and a new release cut as soon as possible, with credit given in the changelog if you'd like.

## Security Model

This app runs entirely on your local machine. It has no backend, no accounts, and no telemetry.

| Aspect | Detail |
|--------|--------|
| **Credential storage** | Session key stored in macOS Keychain — never written to disk in plaintext |
| **Network traffic** | Only contacts `claude.ai/api` — no other endpoints, ever |
| **No shell execution** | Self-update uses `Process` API with explicit paths — no shell string interpolation |
| **Input handling** | Session key input is masked (`SecureField` / `read -s`) — never echoed or logged |
| **Log safety** | `~/.claude-usage/app.log` never contains credentials — only status messages and HTTP codes |
| **Open source** | Every line of `ClaudeUsageApp.swift` and `setup.sh` is readable and auditable |

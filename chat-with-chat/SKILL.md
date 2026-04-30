---
name: chat-with-chat
description: Multi-system web-based AI chat automation via Chrome DevTools Protocol. Send prompts and receive responses from Grok, Claude.ai, and other web UIs without API keys.
---

# Chat with Chat

Automate conversations with web-based AI chat systems (Grok, Claude.ai, etc.) via Chrome remote debugging. Configuration-driven, no API keys required.

## Prerequisites

- **Chrome** running with remote debugging enabled on `:9222`
- **bash** 4.0+ and **Node.js** 16+
- macOS or Linux (tested on macOS 13+)

## Quick Start

### 1. Ensure Chrome is running with remote debugging on :9222

⚠️ **IMPORTANT:** This tool requires the **:9222 Chrome instance** (launched by `./chat-launch.sh`). Do NOT use your personal Chrome or other Chrome windows. Many Chrome instances may be open — verify you're using the correct one.

```bash
./chat-launch.sh
```

Opens Chrome with a persistent debug profile at `~/chrome-debug-profile`. Waits for CDP port `:9222` to be ready. This is the **only** Chrome instance this tool can reach.

### 2. Navigate to your chat system

Open Chrome and navigate to Grok (https://grok.com) or Claude.ai (https://claude.ai). Log in with your credentials. Keep the tab open.

### 3. Check health before chatting (optional)

```bash
./chat-health-check.sh grok
./chat-health-check.sh claude
./chat-health-check.sh                # Check all systems
```

Reports:
- Chrome CDP connectivity
- Open tabs
- Login status for each system
- Input field availability

### 4. Send a prompt and get the response

```bash
./chat-with-chat.sh grok "What is markdown?"
./chat-with-chat.sh claude "Explain closures in JavaScript"
```

Output: AI system's latest response to stdout. Logs all operations to `~/mg/logs/browser-chat-audit.log`.

Health check runs automatically (non-blocking) at the start of each chat-with-chat command.

## Configuration

**chat-tools.conf** defines selector rules for each system:

```ini
[grok]
url_pattern=grok.com
input_selector=.tiptap.ProseMirror
send_button_selector=button[aria-label="Submit"]
message_bubble_class=.message-bubble
response_timeout=10

[claude]
url_pattern=claude.ai
input_selector=[contenteditable="true"]
send_button_selector=button[aria-label="Send prompt"]
message_bubble_class=[data-testid="assistant"]
response_timeout=15
```

**To add a new system**, edit `chat-tools.conf` with five fields per system (name, url_pattern, input_selector, send_button_selector, message_bubble_class, response_timeout). No script editing required.

## Architecture

### chat-with-chat.sh

Main dispatcher. Signature:

```bash
./chat-with-chat.sh <system> "<prompt>"
```

- Runs health check (optional, non-blocking; warns if issues found)
- Ensures correct tab is in focus
- Calls chat-send.sh and chat-wait.sh
- Returns response to stdout

### chat-health-check.sh

Precondition verifier. Checks:
- CDP connectivity on :9222
- Tab exists for system (by URL pattern)
- Login screen detection
- Input field availability

Usage:

```bash
./chat-health-check.sh grok
./chat-health-check.sh              # All systems
```

Returns exit code 0 if all checks pass, 1 if issues found. Recommended to run explicitly before debugging problems.

### chat-send.sh

Generic send operation. Reads config, pastes text into input field, clicks send button.

- Handles tab switching via chat-ensure-tab.js
- Verifies DOM elements exist before interaction
- Anti-spiral safeguards (max 3 retries on input focus)
- Audit logged

### chat-wait.sh

Generic wait/extract operation. Reads config, polls for new message, extracts last bubble.

- Polls with exponential backoff (0.2s → 2s, capped at response_timeout)
- IIFE pattern for safe JavaScript evaluation
- Extracts last `.message-bubble` only (clean, no page cruft)
- Returns extracted text to stdout

### chat-ensure-tab.js

Tab verification utility. Finds and switches to a tab by URL pattern.

```bash
./chat-ensure-tab.js "grok.com"
```

Returns JSON:
```json
{"tabIndex": 2, "url": "https://grok.com/c/...", "title": "Grok"}
```

On error, lists all open tabs for recovery.

## Pitfalls & Troubleshooting

### Chrome not running?

```bash
./chat-launch.sh
```

Launches Chrome daemon on :9222 with persistent debug profile. Can be backgrounded.

### Tab not found?

```bash
./chat-health-check.sh grok      # Lists all open tabs
```

Fix: Open https://grok.com in Chrome and stay on that tab. You must be logged in.

### Login screen detected?

Health check will warn if a login page is detected. Log in to the system in Chrome, then retry.

### Input field not found?

Verify CSS selector in chat-tools.conf matches current DOM. Use browser DevTools inspector (Cmd+Option+I) to find the exact selector.

Update chat-tools.conf and test:

```bash
./chat-with-chat.sh <system> "test"
```

### Response extraction stuck?

- Increase `response_timeout` in chat-tools.conf
- Verify bubble selector is correct in DevTools
- Check audit log: `tail ~/mg/logs/browser-chat-audit.log`

## Files

- **chat-with-chat.sh** — Main dispatcher (61 lines)
- **chat-health-check.sh** — Precondition verifier (111 lines)
- **chat-send.sh** — Generic send (81 lines, config-driven)
- **chat-wait.sh** — Generic wait/extract (74 lines, config-driven)
- **chat-ensure-tab.js** — Tab verification (98 lines, JSON output)
- **chat-launch.sh** — Chrome launcher (31 lines, macOS/Linux)
- **chat-upload.js** — File upload utility (32 lines, multi-file capable)
- **chat-tools.conf** — Selector library (15 lines, INI format)

## Testing

```bash
# Single turn
./chat-with-chat.sh grok "What is a closure?"

# Multi-turn (same tab, context preserved)
./chat-with-chat.sh grok "Explain in simpler terms"
./chat-with-chat.sh grok "Give me an example"

# Different system
./chat-with-chat.sh claude "Summarize the above"

# File upload (before send)
./chat-upload.js ~/path/to/file1.md ~/path/to/file2.md
# Then send normally:
./chat-with-chat.sh claude "Analyze these files"
```

## Anti-Spiral Safeguards

| Failure Mode          | Old Behavior          | New Behavior                              |
|-----------------------|-----------------------|-------------------------------------------|
| Wrong tab             | Silent wrong action   | `browser-ensure-tab` fails fast with tab list |
| Element not found     | JS error / hang       | Explicit error + screenshot + retry       |
| Send button missing   | Click does nothing    | Pre-check + wait for button to appear     |
| Mid-stream read       | Truncated response    | Poll until streaming=false                |
| Agent forgets check   | Spiral                | Make every card operation start with ensure |

**Audit Logging:** Every operation appends to `~/mg/logs/browser-chat-audit.log`:
```
2026-04-30T16:27:00Z | ensure-grok | tab=2 | ok
2026-04-30T16:27:03Z | send-to-grok | 142 chars | success
2026-04-30T16:27:12Z | wait-for-grok | 18s | complete
```

## Future Hardening (Roadmap)

- Vision fallback: on selector fail, screenshot + vision model to describe UI and suggest new selector
- Auto-update selectors: periodic browser-pick.js run + diff against known good
- Session persistence: save tab IDs + restore after Chrome restart
- Rate-limit awareness: detect "slow down" banners and back off

## References

- **pi-skills** (github.com/badlogic/pi-skills) — Upstream generic browser tools (not replicated here)

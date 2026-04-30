# browser-tools

**Purpose** ⟜ agent-assisted web automation via Chrome DevTools Protocol

Chrome running on localhost:9222 with remote debugging. Tools for navigation, evaluation, screenshot, element picking, cookie inspection, and content extraction. Built for reliability and agent clarity.

---

## Design

**Why CDP, not WebDriver?**
- Observable state ⟜ agents can read tabs, DOM, cookies, verify changes
- Deterministic responses ⟜ protocol-stable, not browser-quirk-dependent
- Single async context ⟜ browser-eval runs JS in that context; no hidden threads

**Why puppeteer-core?**
- Remote only ⟜ connects to running Chrome, doesn't bundle/manage it
- Lightweight ⟜ 4MB dependency, not 400MB Chromium
- Our responsibility ⟜ we start Chrome, we manage lifecycle

**Why this matters for agents:**

Agents fail when they:
- Don't verify tab state (pick wrong tab, click fails silently)
- Stack actions without checking results (button clicked but page not updated)
- Assume selectors persist (page reloads, selector breaks)
- Don't distinguish "no result" from "network timeout"

This isn't code quality. It's constraint understanding. The tools expose truth—state, errors, timing—but only if agents listen.

---

## Setup

⊢ Install dependencies once
```bash
cd browser-tools
npm install
```

⊢ Start Chrome (one terminal, keep running)
```bash
./chrome-open-macos.sh
```

Launches Chrome with debugging on `:9222` using debug profile at `~/chrome-debug-profile`. Waits for CDP port to be ready. Profile persists across restarts.

Alternative (cross-platform):
```bash
./browser-start.js
```

---

## Tools

### navigate ⟜ change URL in active tab
```bash
browser-nav.js https://example.com
```

Navigate to URL, wait for DOM. Uses active tab; if none, errors. Exit 0 = success.

**Constraints:**
- Navigates *current* tab only (use `browser-list-tabs.js` to pick)
- `waitUntil: domcontentloaded` ⟜ doesn't wait for all network; checks immediately
- If redirect chain, follows it; timeout = 5s → error

**Errors:** No tabs, connection timeout, goto timeout. All thrown, exit 1.

### eval ⟜ run JavaScript in active tab
```bash
browser-eval.js 'document.title'
browser-eval.js '(function() { return { score: 42, status: "ok" } })()'
```

Executes code in async context of active tab. Returns result to stdout.

**Returns:**
- Primitive: `42`, `"text"`
- Object: keys printed line-by-line
- Array: each item printed, blank line between

**Constraints:**
- Runs in *current* tab only
- Async context (all JS is wrapped as `async function`)
- DOM is live state (queries run, events fire)
- No return = `undefined` printed
- Timeout = 5s connection → error

**Common patterns:**
```bash
# Check if element exists
browser-eval.js 'document.querySelector("#target") !== null'

# Extract state
browser-eval.js '(function() { return { title: document.title, inputs: document.querySelectorAll("input").length }; })()'

# Interact: click, type, submit
browser-eval.js 'document.getElementById("submit").click(); return "clicked"'
```

### pick ⟜ interactive element selection (human-guided)
```bash
browser-pick.js "Click the submit button"
```

Launches interactive picker. User clicks elements to select them (Cmd/Ctrl+click for multiple). Returns CSS selector + parent hierarchy + text + HTML snippet.

**Use when:** Agent can't reliably find selector (multiple similar buttons, dynamic page).

**Constraints:**
- Requires human at browser (shows overlay, waits for keyboard)
- Returns full element info (tag, id, class, text, parents, html)
- ESC cancels, ENTER submits, Cmd/Ctrl+click adds to selection
- For multiple selections: returns array

### screenshot ⟜ capture viewport
```bash
browser-screenshot.js
```

PNG to temp file. Path printed to stdout. Use for visual verification.

### list-tabs ⟜ show all open tabs
```bash
browser-list-tabs.js
```

**Prints:** index, title, URL for each tab. Active tab marked.

**Use before:**
- nav (if > 1 tab, pick which one)
- eval (if > 1 tab, pick which one)

### cookies ⟜ read session state
```bash
browser-cookies.js
```

**Prints:** name, value, domain, path, httpOnly, secure for each cookie.

**Use for:** Debugging auth, verifying session persisted, checking login state.

### content ⟜ extract readable text (HTML → Markdown)
```bash
browser-content.js https://example.com
```

Navigates to URL, waits for load, extracts readable content (skips nav/ads), converts to Markdown.

**Uses:** Mozilla Readability + Turndown. Works on JS-heavy pages (waits for render).

---

## Agent Gotcha: Tab Targeting

⚠️ **Critical:** `browser-eval.js` and `browser-nav.js` operate on the **last tab in the array** (`.at(-1)`), not the visually active tab in your browser UI.

**If mismatch:** Agent reads wrong tab, evaluates wrong page, clicks nothing. Silent failure.

**Always verify first:**
```bash
browser-list-tabs.js
```

See output. Find your target tab (Claude, Grok, GitHub, etc.). Remember the index. If you have multiple tabs and want to switch:

**Problem:** `browser-eval.js` won't let you pick which tab. It just uses the last one.

**Solution:** Use `browser-nav.js` to navigate in the current (last) tab, or use `browser-list-tabs.js` to understand layout and plan operations.

**Pattern:**
```bash
⊢ List all tabs
browser-list-tabs.js

⊢ [Verify which is last]

⊢ If wrong tab is last, navigate it to target page
browser-nav.js https://target-page

⊢ Now eval/pick/screenshot work correctly
browser-eval.js 'document.title'
```

This is not a bug. It's a constraint. The tools are honest about which tab they use. Agents must listen.

---

## Agent Patterns

**Pattern: Verify Before Acting**

⊢ Check current state
```bash
browser-eval.js 'document.getElementById("target") !== null'
```

⊢ Perform action
```bash
browser-eval.js 'document.getElementById("target").click(); return "clicked"'
```

⊢ Verify result changed
```bash
browser-eval.js 'document.querySelector(".success-message") !== null'
```

[If false]✗ → re-read page, adjust selector, retry.

**Pattern: Multiple Tabs**

⊢ List tabs
```bash
browser-list-tabs.js
```

[Need tab N]✓ → Use `browser-nav.js` to switch tabs first, then eval/interact.

**Pattern: Unknown DOM**

⊢ Inspect structure
```bash
browser-eval.js '(function() { return { title: document.title, forms: document.forms.length, buttons: Array.from(document.querySelectorAll("button")).map(b => ({ text: b.textContent.trim(), class: b.className })) }; })()'
```

[Ambiguous]✗ → Use `browser-pick.js` for interactive selection.

**Pattern: Wait for Updates**

⊢ Action may trigger async update
```bash
browser-eval.js 'document.getElementById("submit").click()'
```

⊢ Small delay, then verify
```bash
sleep 0.5 && browser-eval.js 'document.querySelector(".loading") === null'
```

---

## Efficiency

**Don't screenshot to see page state. Query the DOM:**

✗ Bad: `browser-screenshot.js` (2s, PNG, visual inspection)

✓ Good: `browser-eval.js 'document.body.innerHTML.slice(0, 3000)'` (instant, searchable)

**Batch interactions, don't stack calls:**

✗ Bad:
```bash
browser-eval.js 'document.getElementById("a").click()'
browser-eval.js 'document.getElementById("b").click()'
browser-eval.js 'document.getElementById("c").click()'
```

✓ Good:
```bash
browser-eval.js '(function() { 
  ["a", "b", "c"].forEach(id => document.getElementById(id).click()); 
  return "all clicked"; 
})()'
```

**Complex scripts:**

Wrap in IIFE. Run JS, return result. One eval call, not many.

```bash
browser-eval.js '(function() {
  const form = document.querySelector("form");
  const fields = Array.from(form.querySelectorAll("input")).map(i => i.value);
  form.submit();
  return JSON.stringify({ fields, submitted: true });
})()'
```

---

## Constraints & When NOT to Use

**Agent Understanding:**

This toolset is **not** a magical "do anything" browser remote. It's a constraint-based interface.

⟜ **One active tab at a time** — Pick which tab to use. `browser-list-tabs.js` first.

⟜ **DOM is live** — Queries run, events fire, no replay. If page reloads, old selectors break.

⟜ **No wait-for primitives** — If element appears async, add `sleep` or verify state in a loop.

⟜ **Timeouts are final** — 5s connection timeout. If server slow, your script waits. Plan for it.

⟜ **Selectors are fragile** — SPA frameworks change DOM constantly. Use `browser-pick.js` when uncertain.

⟜ **No multi-tab coordination** — Each tool reads/writes current tab. If you need tab A and B in sync, manage that outside.

**Don't use for:**
- Polling every 100ms (use event listeners in JS instead)
- High-frequency form input (type character by character; batch instead)
- Assuming page structure (always inspect first, pick elements interactively if unsure)
- Network requests (agents see DOM state, not XHR; use `browser-eval.js` to check `fetch`/`axios` results if available)

---

## Dependencies

**package.json:**
- puppeteer-core@23.11.1 ⟜ remote browser connection only
- jsdom, cheerio, @mozilla/readability, turndown ⟜ for content extraction

**Why no stealth/extra plugins?** We're not evading detection. We own the browser. Don't add complexity.

---

## References

**Chrome DevTools Protocol:** https://chromedevtools.io/  
**Puppeteer API:** https://pptr.dev/

---

## footer

Design: observable state, deterministic responses, agent clarity.  
Implementation: minimal, focused, testable.  
Reliability: understanding constraints prevents misuse.

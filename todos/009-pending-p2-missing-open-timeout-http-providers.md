---
name: missing-open-timeout-http-providers
description: All three HTTP providers set read_timeout but not open_timeout — unreachable host hangs console exit indefinitely
metadata:
  type: finding
  priority: p2
  tags: [reliability, performance, code-review]
---

## Problem Statement

`Net::HTTP`'s default `open_timeout` is `nil` — it blocks indefinitely waiting for a TCP connection. All three providers set only `read_timeout`. If the API host is unreachable (DNS timeout, network issue, Ollama not running), the console process hangs at exit waiting for a connection that never completes.

This manifests as: developer exits the console, it appears to hang for 75+ seconds (OS TCP timeout), then finally exits. Extremely confusing UX.

## Findings

**providers/anthropic.rb:22-23:**
```ruby
http.use_ssl = true
http.read_timeout = 60
# ← no open_timeout
```

**providers/openai.rb:22-23:** Same pattern.

**providers/ollama.rb:17-18:**
```ruby
http.use_ssl = uri.scheme == "https"
http.read_timeout = 120
# ← no open_timeout — worse since Ollama might not be running
```

## Proposed Solutions

### Option A: Add open_timeout to all three providers
- **Pros:** Fail-fast; clear error message; no indefinite hang
- **Effort:** Trivial

```ruby
http.open_timeout = 10   # fail fast if host unreachable
http.read_timeout = 60   # (120 for Ollama)
```

Ollama: `open_timeout = 5` since localhost should connect immediately.

### Option B: Wrap entire call in Timeout::timeout
- **Pros:** Single location; covers both open and read
- **Cons:** `Timeout` is thread-unsafe and deprecated in many contexts; prefer `open_timeout`/`read_timeout`
- **Effort:** Small
- **Risk:** Low but unnecessary

## Recommended Action

Option A. Three-line change across three files. `open_timeout = 5` for Ollama (localhost), `10` for Anthropic/OpenAI.

## Technical Details

- **Affected files:**
  - `lib/console_historian/providers/anthropic.rb:22`
  - `lib/console_historian/providers/openai.rb:22`
  - `lib/console_historian/providers/ollama.rb:17`

## Acceptance Criteria

- [ ] All three providers have `http.open_timeout` set before `http.request`
- [ ] Anthropic/OpenAI: `open_timeout = 10`
- [ ] Ollama: `open_timeout = 5`
- [ ] `ProviderError` raised (not hang) when host unreachable

## Work Log

- 2026-05-29: Found by performance and security agents in /ce-review pass

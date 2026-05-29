---
name: duplicate-api-key-guard
description: API key nil check exists in both build_provider and provider#call — one location is dead code; inconsistent error handling between the two
metadata:
  type: finding
  priority: p2
  tags: [code-quality, code-review]
---

## Problem Statement

API key validation is split across two places:

1. `build_provider` checks key → returns `nil` if missing (silent, no error)
2. `Provider#call` checks key → raises `ProviderError` if missing (loud, with message)

Since `build_provider` returns `nil` before the provider is ever instantiated, the guard in `Provider#call` is unreachable for the Anthropic and OpenAI cases. For Ollama there's no API key at all. One of these two guards is dead code.

## Findings

**analyzer.rb:74-75 (Anthropic):**
```ruby
key = ENV["ANTHROPIC_API_KEY"]
return nil if key.nil? || key.empty?   # ← silent nil if key missing
Providers::Anthropic.new               # ← provider never instantiated without key
```

**providers/anthropic.rb:18:**
```ruby
raise ProviderError, "ANTHROPIC_API_KEY not set" if @api_key.nil? || @api_key.empty?
# ↑ unreachable — build_provider already returned nil
```

Same pattern in OpenAI. Ollama skips the check entirely (no API key needed).

## Proposed Solutions

### Option A: Remove key checks from build_provider, let providers own validation
- **Pros:** Providers are self-contained; error is explicit (raises, not silent nil)
- **Cons:** `analyze` would need to handle `ProviderError` from instantiation (already does via rescue)
- **Effort:** Small

```ruby
when :anthropic
  Providers::Anthropic.new   # raises ProviderError if key missing
```

### Option B: Remove key checks from provider#call, keep in build_provider
- **Pros:** Centralized check; returns nil silently (current behavior)
- **Cons:** Provider can be instantiated with no key and will fail at call time with a vague error
- **Effort:** Small

### Option C: Keep both (current state, but document intent)
- The `build_provider` check is a fast-exit optimization to avoid creating provider objects; the `call` check is a safety net. Document this explicitly.
- **Effort:** Trivial

## Recommended Action

Option A. Providers should own their own validation. `build_provider` should just select and instantiate — not re-implement each provider's key logic.

## Technical Details

- **Affected files:** `lib/console_historian/analyzer.rb:74-76, 80-82`, `lib/console_historian/providers/anthropic.rb:18`, `lib/console_historian/providers/openai.rb:18`

## Acceptance Criteria

- [ ] API key validation lives in exactly one place per provider
- [ ] Missing key produces an error (not silent nil) that gets logged via the analyzer's rescue
- [ ] No change to observable behavior for end users

## Work Log

- 2026-05-29: Found by simplicity agent in /ce-review pass

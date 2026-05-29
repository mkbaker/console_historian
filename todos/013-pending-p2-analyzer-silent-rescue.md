---
name: analyzer-silent-rescue
description: Analyzer#analyze rescues all errors silently — network failures, JSON errors, timeouts swallowed with no logging; developer never knows why AI analysis failed
metadata:
  type: finding
  priority: p2
  tags: [reliability, code-review]
---

## Problem Statement

`Analyzer#analyze` rescues `ProviderError` and `StandardError` and returns `nil`. No warning is emitted. The recorder falls back to `render_fallback` silently. The developer sees only the saved fallback file with no indication that AI analysis was attempted and failed.

Common silent failures: API key revoked (returns 401), rate limit (returns 429), Ollama not running (connection refused), JSON parse error on malformed response.

## Findings

**analyzer.rb:64:**
```ruby
rescue ProviderError, StandardError
  nil
end
```

Compare with `Recorder#finish` which does `warn "[historian] error saving session: #{e.message}"`. Consistent pattern already exists — just not applied here.

## Proposed Solutions

### Option A: Add warn line before returning nil
- **Pros:** Consistent with existing error handling in recorder.rb; zero behavior change
- **Effort:** Trivial

```ruby
rescue ProviderError, StandardError => e
  warn "[historian] AI analysis failed (#{e.class}): #{e.message}"
  nil
end
```

### Option B: Add debug-level logging (configurable verbosity)
- **Pros:** Users can suppress the warning
- **Cons:** Adds configuration surface area
- **Effort:** Small

## Recommended Action

Option A. One-line change, consistent with existing pattern. The warning goes to stderr and is immediately visible at console exit.

## Technical Details

- **Affected file:** `lib/console_historian/analyzer.rb:64`

## Acceptance Criteria

- [x] `warn` called with error class and message when analysis fails
- [x] Fallback still used on failure (behavior unchanged)
- [x] Output format consistent with `[historian]` prefix used elsewhere

## Work Log

- 2026-05-29: Found by quality and architecture agents in /ce-review pass

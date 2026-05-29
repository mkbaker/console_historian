---
name: redundant-require-relative-build-provider
description: build_provider calls require_relative for provider files already loaded at top-level — dead code misleads maintainers into thinking providers are lazy-loaded
metadata:
  type: finding
  priority: p2
  tags: [code-quality, code-review]
---

## Problem Statement

`Analyzer#build_provider` calls `require_relative "providers/anthropic"` (and openai, ollama) before instantiating each provider. All three files are already unconditionally required in `lib/console_historian.rb:11-13`. The `require_relative` calls in `build_provider` are no-ops after the first load.

The presence of these calls implies lazy loading — a maintainer might think removing the top-level requires in `console_historian.rb` would still work. It would not.

## Findings

**console_historian.rb:11-13:**
```ruby
require_relative "console_historian/providers/anthropic"
require_relative "console_historian/providers/openai"
require_relative "console_historian/providers/ollama"
```

**analyzer.rb:71-87:**
```ruby
when :anthropic
  require_relative "providers/anthropic"   # ← already loaded, no-op
  ...
when :openai
  require_relative "providers/openai"      # ← no-op
  ...
when :ollama
  require_relative "providers/ollama"      # ← no-op
```

## Proposed Solutions

### Option A: Remove require_relative from build_provider (Recommended)
- **Pros:** Code matches reality; no confusion about load strategy
- **Effort:** Trivial (delete 3 lines)

### Option B: Switch to true lazy loading
- Remove top-level requires from `console_historian.rb`
- Keep `require_relative` in `build_provider`
- **Pros:** Avoids loading HTTP libraries when provider is `:none`
- **Cons:** More complex load path; requires testing each provider loads correctly in isolation
- **Effort:** Small

## Recommended Action

Option A unless startup performance is a concern (it's not for a dev-only gem). Delete the 3 lines from `build_provider`.

## Technical Details

- **Affected file:** `lib/console_historian/analyzer.rb:71, 79, 84`

## Acceptance Criteria

- [ ] `require_relative` calls removed from `build_provider`
- [ ] All provider specs still pass (providers remain loadable)
- [ ] `Analyzer#build_provider` still instantiates correct provider class

## Work Log

- 2026-05-29: Found by simplicity, architecture, and quality agents in /ce-review pass

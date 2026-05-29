---
name: ollama-never-auto-detected
description: Ollama documented as supported provider but never auto-detected by Configuration#detect_provider — requires manual config, surprising to users who install Ollama
metadata:
  type: finding
  priority: p3
  tags: [ux, code-quality, code-review]
---

## Problem Statement

`detect_provider` checks for `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` but has no Ollama detection. Ollama requires no API key — it should be detectable by whether it's running on the default port. Users who install Ollama expecting auto-detection (as documented alongside Anthropic/OpenAI) must manually set `ai_provider: :ollama` in the initializer.

## Findings

**configuration.rb:17-22:**
```ruby
def detect_provider
  return :anthropic if key?("ANTHROPIC_API_KEY")
  return :openai if key?("OPENAI_API_KEY")
  :none   # ← Ollama never returned
end
```

## Proposed Solutions

### Option A: Check if Ollama is running (HTTP probe)
- **Pros:** True auto-detection; consistent with Anthropic/OpenAI behavior
- **Cons:** Adds a network probe at Rails boot; startup delay if Ollama is not running
- **Effort:** Medium

```ruby
def ollama_running?
  require "net/http"
  uri = URI(ENV.fetch("OLLAMA_HOST", "http://localhost:11434"))
  Net::HTTP.get_response(uri).is_a?(Net::HTTPSuccess)
rescue
  false
end
```

### Option B: Check OLLAMA_HOST env var as signal
- **Pros:** No network probe; if user set OLLAMA_HOST they intend to use Ollama
- **Cons:** Default host env var not set by default, so this only helps explicit env var users
- **Effort:** Trivial

```ruby
return :ollama if ENV.key?("OLLAMA_HOST")
```

### Option C: Document only — "Ollama requires manual config"
- **Pros:** No code change; honest
- **Cons:** Inconsistency with Anthropic/OpenAI auto-detection remains
- **Effort:** Trivial

## Recommended Action

Option C short-term (document it), Option B if OLLAMA_HOST is commonly set, Option A only if the startup probe cost is acceptable (probably not for a Rails boot-path check).

## Technical Details

- **Affected file:** `lib/console_historian/configuration.rb:17-22`, `README.md`

## Acceptance Criteria

- [ ] README explicitly states Ollama requires `ai_provider: :ollama` in initializer (does not auto-detect)
- [ ] OR: `OLLAMA_HOST` env var triggers Ollama selection

## Work Log

- 2026-05-29: Found by simplicity agent in /ce-review pass

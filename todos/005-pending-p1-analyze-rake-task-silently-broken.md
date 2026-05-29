---
name: analyze-rake-task-silently-broken
description: console_historian:analyze wraps saved markdown as single entry — always hits entries.length < 3 guard, silently returns nil, task is non-functional
metadata:
  type: finding
  priority: p1
  tags: [correctness, code-review]
---

## Problem Statement

The `console_historian:analyze` rake task is advertised in the README as a way to re-run LLM analysis on a saved session. It is completely broken. It wraps the saved markdown file as a single `{ input: raw, ... }` entry, then calls `Analyzer#analyze` which immediately returns `nil` for `entries.length < 3`. The task always prints "Analysis failed or provider not configured" regardless of API key state.

Additionally, the intent is architecturally impossible with current storage: only the final rendered markdown is saved — the original structured entries (per-command hash array) are never persisted.

## Findings

**railtie.rb:54-62:**
```ruby
entries = [{ input: raw, output: "", timestamp: Time.now.iso8601 }]
result = ConsoleHistorian::Analyzer.new.analyze(entries, {})
# ↑ always nil — entries.length (1) < 3
if result
  path = ConsoleHistorian::Storage.new.save(stem, result)
  puts "Saved › #{path}"
else
  puts "Analysis failed or provider not configured"  # ← always reached
end
```

**analyzer.rb:53:**
```ruby
return nil if entries.length < 3  # ← kills the task every time
```

## Proposed Solutions

### Option A: Store raw entries as JSON sidecar on session save (Correct, More Work)
- **Pros:** Enables real re-analysis; enables future features (re-analyze with different provider, search entries)
- **Cons:** Changes storage format; two files per session
- **Effort:** Medium

In `Recorder#finish`:
```ruby
Storage.new.save_entries(@stem, @entries)  # saves stem.json
Storage.new.save(@stem, content)           # saves stem.md
```

Then the task loads `stem.json` and passes real entries to `Analyzer#analyze`.

### Option B: Fix the task to bypass the minimum entry guard (Pragmatic)
- **Pros:** No storage format change; minimal code change
- **Cons:** Sends already-rendered markdown to LLM which designed the prompt for structured entries — will produce poor results
- **Effort:** Small

Add a `force: true` param to `analyze` bypassing the length check, and call the provider directly with a re-analysis prompt.

### Option C: Remove the rake task (Minimal)
- **Pros:** Removes a broken, misleading feature
- **Cons:** Removes documented functionality
- **Effort:** Tiny

## Recommended Action

Option C short-term (remove the broken task), Option A medium-term (sidecar JSON). Option B produces junk LLM output and should not be shipped.

## Technical Details

- **Affected file:** `lib/console_historian/railtie.rb:47-63`
- **Related:** `lib/console_historian/storage.rb` (would need `save_entries`/`load_entries`)

## Acceptance Criteria

- [x] If removing: `rake console_historian:analyze` is removed from railtie and README
- [ ] If implementing sidecar: `Recorder#finish` saves `stem.json` with structured entries; task reloads and re-analyzes correctly
- [ ] No silent "Analysis failed" when provider is properly configured

## Work Log

- 2026-05-29: Found by simplicity, architecture, and security agents in /ce-review pass

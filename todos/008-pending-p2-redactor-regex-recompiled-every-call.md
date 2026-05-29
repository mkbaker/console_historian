---
name: redactor-regex-recompiled-every-call
description: Redactor builds new Regexp objects on every redact() call — 6 compilations per command, compounding at 100+ commands per session
metadata:
  type: finding
  priority: p2
  tags: [performance, code-review]
---

## Problem Statement

`Redactor#redact` calls `Regexp.escape(pattern.to_s)` and interpolates a regex string inside the loop for every call. Ruby does not cache dynamically-built regexes from string interpolation — each `gsub(/(\b#{pat}\b...)/)` compiles a fresh `Regexp` object.

With 6 default patterns and 100 commands: 600 regex compilations per session. At 1,000 commands: 6,000.

## Findings

**redactor.rb:14-22:**
```ruby
def redact(text)
  return text unless text.is_a?(String)

  @patterns.each do |pattern|
    pat = Regexp.escape(pattern.to_s)             # ← recomputed every call
    text = text.gsub(/(\b#{pat}\b\s*(?:=>|:)\s*)(?:"[^"]*"|'[^']*'|\S+)/i) do
      "#{Regexp.last_match(1)}#{REDACTED}"
    end
  end
  text
end
```

`redact` is called twice per command (once for `input`, once for `output`) in `redact_entries`.

## Proposed Solutions

### Option A: Compile patterns once in initialize (Recommended)
- **Pros:** Eliminates compilation cost entirely; zero behavior change
- **Cons:** None
- **Effort:** Small

```ruby
def initialize(patterns = nil)
  @patterns = patterns || ConsoleHistorian.configuration.redact
  @compiled = @patterns.map do |pattern|
    pat = Regexp.escape(pattern.to_s)
    /(\b#{pat}\b\s*(?:=>|:)\s*)(?:"[^"]*"|'[^']*'|\S+)/i
  end
end

def redact(text)
  return text unless text.is_a?(String)
  @compiled.each do |regex|
    text = text.gsub(regex) { "#{Regexp.last_match(1)}#{REDACTED}" }
  end
  text
end
```

## Recommended Action

Option A. One-line change to initialize, eliminates all compilation overhead.

## Technical Details

- **Affected file:** `lib/console_historian/redactor.rb:7-22`

## Acceptance Criteria

- [x] `Redactor#initialize` pre-compiles all pattern regexes into `@compiled`
- [x] `Redactor#redact` uses `@compiled` array
- [x] All existing redactor specs pass unchanged
- [x] No new `Regexp` object created inside `redact`

## Work Log

- 2026-05-29: Found by performance agent in /ce-review pass

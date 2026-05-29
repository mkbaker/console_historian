---
name: missing-spec-coverage
description: Multiple untested paths across truncator, redactor, analyzer, recorder, and all three providers — several correspond to known bugs
metadata:
  type: finding
  priority: p3
  tags: [testing, code-review]
---

## Problem Statement

Several critical paths have no spec coverage. Some correspond to known correctness bugs (see todos #004, #010). Provider classes have zero specs.

## Findings

**Untested scenarios with known bugs or risk:**

1. **`truncate_ar` with `>` in field value** — P1 correctness bug (#004), no regression test
2. **`truncate_ar` fallback to `truncate_generic`** — `boundary = nil` path untested
3. **`format_log` with backtick shell expression in entry[:input]** — P2 code fence injection (#010), untested
4. **`Redactor#redact` with symbol pattern containing non-word chars** — `\b` boundary behavior for `:token` as a symbol key untested
5. **`Redactor#redact` with multi-word value** — `\S+` only captures first word, rest leaks; not tested
6. **`pre_submission_truncated: true` flag** — set but never asserted in any spec
7. **`Recorder#finish`** — session save path, `generate_stem`, `at_exit` integration — zero coverage
8. **`Redactor#redact` with empty patterns list** — should be a no-op; untested
9. **`Configuration#detect_provider`** — auto-detection from env vars untested; priority (anthropic wins when both set) untested
10. **All three provider classes** — zero specs; no stub of Net::HTTP to verify request shape/headers/error handling

## Proposed Solutions

### Add specs for each category above

**Priority order:**
1. `truncate_ar` with `>` in field value (blocks P1 fix verification)
2. `format_log` with backtick input (blocks P2 fix verification)
3. Provider specs with stubbed `Net::HTTP` (high value, currently zero coverage)
4. `Configuration#detect_provider` with env var manipulation
5. Remaining edge cases

**Provider spec example:**
```ruby
# spec/console_historian/providers/anthropic_spec.rb
describe ConsoleHistorian::Providers::Anthropic do
  it "posts correct headers and body" do
    stub = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(stub)
    # ...
  end
  
  it "raises ProviderError on non-200 response" do
    # ...
  end
end
```

## Technical Details

- **Affected files:** `spec/console_historian/truncator_spec.rb`, `spec/console_historian/analyzer_spec.rb`, `spec/console_historian/redactor_spec.rb`, missing provider specs

## Acceptance Criteria

- [ ] Spec added for `truncate_ar` with `>` inside field value
- [ ] Spec added for `format_log` with triple-backtick input
- [ ] Spec for at least one provider with stubbed Net::HTTP (request shape, error handling)
- [ ] `Configuration#detect_provider` spec with env var variants
- [ ] `pre_submission_truncated` flag asserted in truncator spec

## Work Log

- 2026-05-29: Found by quality agent in /ce-review pass

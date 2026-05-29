---
name: redactor-systematic-blind-spots
description: Redactor misses variable assignment form, output-side values, camelCase keys, multi-word values, and bracket accessor patterns — sensitive data leaks through
metadata:
  type: finding
  priority: p2
  tags: [security, correctness, code-review]
---

## Problem Statement

The redactor uses keyword-proximity regex matching. It only catches `key: value` and `key => value` forms. Multiple common patterns are not redacted, and the output side (where raw values appear without keyword context) is fundamentally unredactable by this approach.

## Findings

**Confirmed bypass patterns:**

1. **Variable assignment** — `password = "mysecret"` — no `:` or `=>` after keyword, never redacted
2. **AR inspect output** — `#<User id: 1, password_digest: "abc123">` — `password_digest` doesn't match `\bpassword\b` (underscore is a word char, so `password_` breaks the `\b` anchor)
3. **Output-side values** — `User.first.password` outputs `"hunter2"` with no keyword context — fundamentally unredactable by keyword-proximity
4. **camelCase variants** — `{apiKey: "my-key"}` — pattern is `api_key`, not `apiKey`
5. **Multi-word values** — `{token: abc def ghi}` — `\S+` captures only `abc`; ` def ghi` leaks
6. **Bracket accessors** — `config[:password] = "value"` — `:password` followed by `]`, not `:` or `=>`

**redactor.rb:18 — the regex:**
```ruby
/(\b#{pat}\b\s*(?:=>|:)\s*)(?:"[^"]*"|'[^']*'|\S+)/i
```

## Proposed Solutions

### Option A: Expand default pattern list + document limitations
- **Pros:** Low effort, real improvement; honest about remaining limits
- **Cons:** Doesn't fix output-side leaks or variable assignment
- **Effort:** Small

Add to default patterns: `password_digest`, `encrypted_password`, `auth_token`, `access_token`, `refresh_token`, `private_key`, `client_secret`, `bearer_token`, `api_secret`.

Add to README: "Redaction is keyword-proximity based. Raw output values (e.g. from `.password` method calls) are not redacted. Use `ai_provider: :none` for sessions with sensitive data."

### Option B: Add variable assignment form to regex
- **Pros:** Catches `password = "value"` form
- **Cons:** More false positives; still doesn't fix output-side
- **Effort:** Small

```ruby
/(\b#{pat}\b\s*(?:=>|:|=)\s*)(?:"[^"]*"|'[^']*'|\S+)/i
```

### Option C: Warn at session start if redaction patterns are active
- **Pros:** Informs developer of limitations
- **Effort:** Tiny

```
[historian] note: redaction is keyword-proximity only — raw output values are not scrubbed
```

## Recommended Action

Option A + Option C. Expand the default list and add the warning + README clarification. Option B has unacceptable false-positive risk.

## Technical Details

- **Affected files:** `lib/console_historian/configuration.rb:12`, `lib/console_historian/redactor.rb`, `README.md`

## Acceptance Criteria

- [x] Default redact list includes `password_digest`, `encrypted_password`, `auth_token`, `access_token`, `refresh_token`, `private_key`, `client_secret`
- [x] README documents redaction limitations clearly
- [x] Session-start message (or README) warns about output-side values
- [x] Specs added for `password_digest` and other new default patterns

## Work Log

- 2026-05-29: Found by security-sentinel agent in /ce-review pass
- 2026-05-29: Implemented Option A + Option C

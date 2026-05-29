---
name: branch-truncation-applied-twice
description: 30-char branch name truncation applied in both current_branch and sanitize_branch — double truncation, responsibility split between wrong methods
metadata:
  type: finding
  priority: p3
  tags: [code-quality, code-review]
---

## Problem Statement

`current_branch` truncates to 30 chars at line 124 (`out[0, 30]`). Then `sanitize_branch` also truncates to 30 chars at line 138. The 30-char limit is applied twice to the same string. After sanitization (which can only remove or replace chars, never add), a 30-char input is always ≤ 30 chars anyway, so the second truncation is always a no-op.

The truncation responsibility is split: `current_branch` shouldn't know about the 30-char constraint — that's a file naming concern that belongs in `sanitize_branch`.

## Findings

**recorder.rb:121-124:**
```ruby
def current_branch
  out = `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
  out.empty? ? nil : out[0, 30]   # ← first truncation
rescue StandardError
  nil
end
```

**recorder.rb:136-138:**
```ruby
def sanitize_branch(branch)
  return nil if branch.nil? || branch.empty?
  branch.gsub(/[^a-zA-Z0-9]/, "-").gsub(/-{2,}/, "-").gsub(/\A-|-\z/, "")[0, 30]  # ← second truncation
end
```

## Proposed Solutions

### Fix: Remove truncation from current_branch, keep in sanitize_branch
```ruby
def current_branch
  out = `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
  out.empty? ? nil : out   # ← no truncation here
rescue StandardError
  nil
end
```

`sanitize_branch` already owns the 30-char limit. Single responsibility.

## Technical Details

- **Affected file:** `lib/console_historian/recorder.rb:124`

## Acceptance Criteria

- [ ] `current_branch` returns full branch name without truncation
- [ ] `sanitize_branch` truncates to 30 chars (unchanged)
- [ ] Branch names longer than 30 chars before sanitization still produce ≤ 30 char stems

## Work Log

- 2026-05-29: Found by quality agent in /ce-review pass

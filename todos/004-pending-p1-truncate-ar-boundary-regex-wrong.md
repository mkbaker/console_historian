---
name: truncate-ar-boundary-regex-wrong
description: truncate_ar uses > regex to find record boundaries — fires prematurely on > inside field values, producing malformed output and wrong record count
metadata:
  type: finding
  priority: p1
  status: completed
  tags: [correctness, code-review]
---

## Problem Statement

`truncate_ar` finds the first AR record boundary using `/>,?\s*(?:\n|\z)/`. This fires on the first `>` followed by comma/newline in the output — which is any field value containing `>`, not just the record-closing `>`.

Example: `#<User id: 1, name: "a>b", email: "x@y.com">` → boundary found inside `"a>b"` → `first` is truncated mid-record. The LLM sees a malformed object and the record count is wrong.

## Findings

**truncator.rb:40-46:**
```ruby
def truncate_ar(output)
  boundary = output.index(/>,?\s*(?:\n|\z)/)  # ← fires on > in field values
  if boundary
    first = output[0, boundary + 1]
    rest = output[(boundary + 1)..]
    record_count = rest.to_s.scan(/#</).length
    record_count > 0 ? "#{first}\n[... #{record_count} more records truncated]" : first
  else
    truncate_generic(output)
  end
end
```

Real-world trigger: any User/model with name, description, url, or html field containing `>`. Also triggers on: AR timestamps in older formats, hash fields, nested objects.

No spec covers this case.

## Proposed Solutions

### Option A: Angle-bracket depth tracker (Correct)
- **Pros:** Correctly handles nested `<>` by tracking depth
- **Cons:** More code; per-character scan
- **Effort:** Medium

```ruby
def find_first_record_end(output)
  depth = 0
  output.each_char.with_index do |ch, i|
    depth += 1 if ch == "<"
    depth -= 1 if ch == ">"
    return i if depth.zero? && ch == ">"
  end
  nil
end

def truncate_ar(output)
  boundary = find_first_record_end(output)
  if boundary
    first = output[0, boundary + 1]
    rest = output[(boundary + 1)..]
    rest.to_s.empty? ? first : "#{first}\n[... more records truncated]"
  else
    truncate_generic(output)
  end
end
```

### Option B: Match only `>\n` or `>, ` at start of next record (Heuristic)
- **Pros:** Simpler regex
- **Cons:** Still fragile for complex inspect output
- **Effort:** Small

```ruby
boundary = output.index(/>\n#<|>, #<|\z/)
```

### Option C: Fallback to truncate_generic for AR output (Conservative)
- **Pros:** No false truncation; safe
- **Cons:** Loses the "first AR record only" optimization
- **Effort:** Minimal

## Recommended Action

Option A for correctness. Also drop the record count from the truncation message — "more records truncated" is sufficient and avoids the scan cost.

## Technical Details

- **Affected file:** `lib/console_historian/truncator.rb:40-46`

## Acceptance Criteria

- [x] `truncate_ar('#<User id: 1, name: "a>b", email: "x@y.com">')` returns the full record, not a truncated mid-record string
- [x] Collection with 3 records truncates after the first correctly
- [x] Spec added: field value containing `>`, nested object in field, empty collection
- [x] No regression on existing truncator specs

## Work Log

- 2026-05-29: Found by quality agent in /ce-review pass

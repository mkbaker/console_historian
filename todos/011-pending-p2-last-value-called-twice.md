---
name: last-value-called-twice
description: IRBContextHook calls last_value twice per command — second call may return different value; expensive inspect on large objects runs twice
metadata:
  type: finding
  priority: p2
  tags: [correctness, performance, code-review]
---

## Problem Statement

`IRBContextHook#evaluate` calls `last_value` twice: once for `.inspect` (output) and again for `.class.name` (return_class). `last_value` is an IRB method that returns the result of the last evaluated expression. If IRB state changes between calls (unlikely but possible in multithreaded contexts or with IRB hooks), the two calls could return different objects. More practically, `.inspect` on a large ActiveRecord result set can be extremely expensive — running it twice doubles the cost.

## Findings

**recorder.rb:19-28:**
```ruby
output = begin
  last_value.inspect        # ← first call, expensive inspect
rescue StandardError
  ""
end
return_class = begin
  last_value.class.name     # ← second call, could differ
rescue StandardError
  nil
end
```

## Proposed Solutions

### Option A: Capture last_value once (Recommended)
- **Pros:** Single call; consistent output and return_class from same object; eliminates double-inspect risk
- **Effort:** Small

```ruby
val = begin
  last_value
rescue StandardError
  nil
end
output = Truncator.new.truncate_output(val&.inspect.to_s, val&.class&.name)
return_class = val&.class&.name
```

Or more simply:
```ruby
val = last_value rescue nil
output = (val.inspect rescue "")
return_class = (val.class.name rescue nil)
```

## Recommended Action

Option A. Capture `last_value` once, derive both `output` and `return_class` from the same object reference.

## Technical Details

- **Affected file:** `lib/console_historian/recorder.rb:19-28`

## Acceptance Criteria

- [ ] `last_value` called exactly once per command evaluation in `IRBContextHook#evaluate`
- [ ] `output` and `return_class` derived from same captured object
- [ ] No behavior change for normal cases
- [ ] Exception in `last_value` itself still handled gracefully

## Work Log

- 2026-05-29: Found by performance agent in /ce-review pass

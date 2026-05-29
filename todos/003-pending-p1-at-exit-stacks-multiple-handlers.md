---
name: at-exit-stacks-multiple-handlers
description: at_exit registered per begin_session call — multiple sessions in one process register multiple handlers causing duplicate LLM calls and file writes
metadata:
  type: finding
  priority: p1
  tags: [correctness, performance, code-review]
---

## Problem Statement

`at_exit { finish }` is called inside `begin_session`. Ruby's `at_exit` stack is append-only. Each call to `Recorder.start` (test suite, double-boot, restarted console) pushes another handler. The `@finished` flag guards a single instance but multiple `Recorder` instances each have their own `@finished = false`, so all fire on process exit.

Result: N calls to `Recorder.start` → N LLM API calls + N file writes on exit.

## Findings

**recorder.rb:70:**
```ruby
at_exit { finish }  # ← inside begin_session, no dedup guard
```

**recorder.rb:107-111:**
```ruby
def hook_irb
  return if IRB::Context.ancestors.include?(IRBContextHook)
  IRB::Context.prepend(IRBContextHook)
end
```

`hook_irb` correctly guards against double-prepend. `at_exit` has no equivalent guard.

The module-level `@current_recorder` is overwritten by each `begin_session`, so the first recorder is orphaned — its `at_exit` closure still holds `self` (the old instance), fires, and writes using stale state.

## Proposed Solutions

### Option A: Class-level registration flag (Recommended)
- **Pros:** Simple, mirrors the existing `hook_irb` guard pattern
- **Cons:** None
- **Effort:** Small

```ruby
def begin_session
  # ... existing setup ...
  unless self.class.instance_variable_get(:@exit_registered)
    self.class.instance_variable_set(:@exit_registered, true)
    at_exit { ConsoleHistorian.current_recorder&.finish }
  end
end
```

This also decouples the `at_exit` target from a captured `self`, so the handler always finishes whatever recorder is currently active.

### Option B: Guard with raise if already recording
- **Pros:** Makes double-start a loud error
- **Cons:** Could break test suites that call `Recorder.start` multiple times
- **Effort:** Small

```ruby
def begin_session
  raise "Recorder already active" if ConsoleHistorian.current_recorder&.recording?
  # ...
end
```

### Option C: Register at_exit once at module load time
- **Pros:** Most predictable
- **Cons:** Runs even if gem never used
- **Effort:** Small

## Recommended Action

Option A. Matches the existing `hook_irb` guard pattern; decouples the closure from `self`.

## Technical Details

- **Affected file:** `lib/console_historian/recorder.rb:70`
- **Also affects:** `spec/spec_helper.rb` — need to reset `Recorder.instance_variable_set(:@exit_registered, nil)` between tests

## Acceptance Criteria

- [x] Calling `Recorder.start` twice in one process registers exactly one `at_exit` handler
- [x] `at_exit` fires the currently active recorder, not a stale instance
- [x] Spec added verifying no duplicate file writes on multi-start scenarios
- [x] `spec_helper.rb` resets `@exit_registered` between tests

## Work Log

- 2026-05-29: Found independently by security, performance, architecture, and quality agents in /ce-review pass

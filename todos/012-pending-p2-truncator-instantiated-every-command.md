---
name: truncator-instantiated-every-command
description: Truncator.new called on every IRB command evaluation — unnecessary allocation churn; config singleton re-looked up per command
metadata:
  type: finding
  priority: p2
  tags: [performance, code-review]
---

## Problem Statement

`IRBContextHook#evaluate` calls `Truncator.new` on every command. `Truncator#initialize` looks up `ConsoleHistorian.configuration` (already memoized). The configuration doesn't change mid-session. This creates one unnecessary object allocation per command.

## Findings

**recorder.rb:31:**
```ruby
output: Truncator.new.truncate_output(output, return_class),
```

Called on every IRB command. `Truncator.new` → `ConsoleHistorian.configuration` lookup → `@config` set. Repeated N times for N commands.

IRBContextHook is a module prepended onto IRB::Context, so it doesn't have direct access to the Recorder instance's ivars. The recorder is accessed via `ConsoleHistorian.current_recorder`.

## Proposed Solutions

### Option A: Store Truncator on Recorder, expose via current_recorder
- **Pros:** Single allocation at session start; Truncator config fixed for session
- **Effort:** Small

```ruby
# recorder.rb — in begin_session:
@truncator = Truncator.new

# recorder.rb — add public accessor:
attr_reader :truncator

# IRBContextHook:
output: ConsoleHistorian.current_recorder.truncator.truncate_output(output, return_class)
```

### Option B: Store Truncator on ConsoleHistorian module
- **Pros:** No interface change needed on Recorder
- **Cons:** More global state
- **Effort:** Small

### Option C: Leave as-is (acceptable for dev tool)
- Since this is a dev tool and GC pressure from one small object per console command is minimal, this is low-priority.
- **Effort:** None
- **Risk:** None

## Recommended Action

Option A alongside fixing the `last_value` double-call (#011). Together they clean up the hot path without major restructuring.

## Technical Details

- **Affected file:** `lib/console_historian/recorder.rb:31, 59-71`

## Acceptance Criteria

- [ ] `Truncator.new` called once per session, not once per command
- [ ] `IRBContextHook#evaluate` uses the recorder's cached truncator
- [ ] All truncator specs pass unchanged

## Work Log

- 2026-05-29: Found by performance and architecture agents in /ce-review pass

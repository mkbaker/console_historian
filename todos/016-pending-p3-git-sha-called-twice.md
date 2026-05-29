---
name: git-sha-called-twice
description: git_sha shells out to git rev-parse twice per session — once in generate_stem, once in finish metadata
metadata:
  type: finding
  priority: p3
  tags: [performance, code-review]
---

## Problem Statement

`git_sha` shells out via backtick to `git rev-parse --short HEAD` twice per session: once in `generate_stem` (called at session start) and once in `Recorder#finish` (called at exit) as part of the metadata hash. Same subprocess, same result, two forks.

## Findings

**recorder.rb:118:** `sha_part = git_sha` (inside `generate_stem`, called from `begin_session`)

**recorder.rb:92:** `git_sha: git_sha` (inside `finish`)

Both calls are in the same `Recorder` instance. The git SHA for a session cannot change between session start and exit (without a commit during the session, which is an edge case worth noting but not handling).

## Proposed Solutions

### Option A: Cache in begin_session
```ruby
def begin_session
  @started_at = Time.now
  @git_sha = git_sha         # ← cache once
  @stem = generate_stem
  # ...
end

def generate_stem
  sha_part = @git_sha        # ← use cached
  # ...
end

def finish
  metadata = {
    git_sha: @git_sha,       # ← use cached
    # ...
  }
end
```

## Recommended Action

Option A. Simple ivar cache eliminates one subprocess fork.

## Technical Details

- **Affected file:** `lib/console_historian/recorder.rb:92, 118`

## Acceptance Criteria

- [ ] `git_sha` (subprocess) called once per session lifecycle
- [ ] `@git_sha` ivar set in `begin_session`, used in `generate_stem` and `finish`

## Work Log

- 2026-05-29: Found by simplicity agent in /ce-review pass

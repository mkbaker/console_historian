---
name: path-traversal-storage-rake-tasks
description: Unsanitized stem in Storage#file_path allows path traversal — arbitrary file read/overwrite via rake tasks
metadata:
  type: finding
  priority: p1
  status: completed
  tags: [security, code-review]
---

## Problem Statement

`stem` flows from rake task arguments directly into `Storage#file_path` with no sanitization. A stem of `../../some/app/file` produces a path outside `save_path`. The `show` task leaks arbitrary file contents; the `analyze` task overwrites arbitrary `.md` files with LLM output.

## Findings

**railtie.rb:38** — `show` task: `stem = args[:stem]` → `Storage.new.load(stem)` → `File.read(path)`. Only checks non-nil/non-empty.

**railtie.rb:49** — `analyze` task: same stem → `Storage.new.save(stem, result)` → `File.write(path, content)`. Overwrites target file.

**storage.rb:32** — `file_path` constructs path with no validation:
```ruby
def file_path(stem)
  File.join(@config.save_path, "#{stem}.md")
end
```

## Proposed Solutions

### Option A: Sanitize at call site in railtie (Fast, Minimal)
- **Pros:** Localized, immediate fix, easy to review
- **Cons:** Defense-in-depth missing — Storage still vulnerable if called elsewhere
- **Effort:** Small
- **Risk:** Low

```ruby
stem = File.basename(args[:stem].to_s).gsub(/[^a-zA-Z0-9_\-]/, "")
abort "Invalid stem" if stem.empty?
```

### Option B: Harden Storage#file_path (Recommended)
- **Pros:** Single fix covers all current and future callers; defense-in-depth
- **Cons:** Slight behavior change — existing callers with dots in stems would fail (none currently)
- **Effort:** Small
- **Risk:** Very low

```ruby
def file_path(stem)
  safe = File.basename(stem.to_s).gsub(/[^a-zA-Z0-9_\-]/, "")
  raise ArgumentError, "Invalid session stem: #{stem.inspect}" if safe.empty?
  File.join(@config.save_path, "#{safe}.md")
end
```

### Option C: Both (Belt and Suspenders)
Apply both A and B.
- **Effort:** Small
- **Risk:** None

## Recommended Action

Option C. Fix `Storage#file_path` as primary defense, sanitize at rake task call site as secondary.

## Technical Details

- **Affected files:** `lib/console_historian/storage.rb:32`, `lib/generators/console_historian/install/install_generator.rb`
- **Affected rake tasks:** `console_historian:show`, `console_historian:analyze`

## Acceptance Criteria

- [x] `Storage#file_path("../../etc/passwd")` raises `ArgumentError`
- [x] `rake console_historian:show["../../etc/passwd"]` aborts with clear message
- [x] Valid stems like `2026-05-29_14-14_main_abc1234` still work
- [x] Spec added for `Storage#file_path` with traversal attempts

## Work Log

- 2026-05-29: Found by security-sentinel agent in /ce-review pass

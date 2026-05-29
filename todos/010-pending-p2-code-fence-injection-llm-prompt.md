---
name: code-fence-injection-llm-prompt
description: Raw entry[:input] injected into Markdown code fence — backtick strings in Ruby commands break the fence, corrupting the LLM prompt structure
metadata:
  type: finding
  priority: p2
  tags: [correctness, code-review]
---

## Problem Statement

`Analyzer#format_log` wraps each command in a Markdown code fence. If a command contains triple backticks (common in Ruby — backtick strings execute shell commands), the fence is terminated early. The LLM receives malformed Markdown and the structured prompt collapses.

Real example: a developer runs `` `git log --oneline -5` `` in the console. This is a valid Ruby expression. The formatted entry becomes:

```
### Command 3 (2026-05-29T14:22:00Z)
```ruby
`git log --oneline -5`
```
```

The inner triple backtick closes the outer fence. The rest of the log is outside any code block.

## Findings

**analyzer.rb:93-96:**
```ruby
lines << "```ruby"
lines << entry[:input].to_s       # ← can contain ``` 
lines << "```"
```

This is the string sent verbatim to the LLM. Backtick shell execution (`` `cmd` ``) is a normal Ruby pattern used in console sessions.

## Proposed Solutions

### Option A: Replace ``` with ''' in entry input before formatting
- **Pros:** Simple, safe; LLM still understands the intent
- **Cons:** Slight input mutation; backtick strings appear with quotes in the LLM context
- **Effort:** Small

```ruby
lines << entry[:input].to_s.gsub("```", "'''")
```

### Option B: Use 4-space indented code blocks instead of fenced
- **Pros:** Cannot be broken by content; valid CommonMark
- **Cons:** Less readable if LLM is trained on fenced blocks; indentation changes format
- **Effort:** Small

```ruby
entry[:input].to_s.each_line { |l| lines << "    #{l}" }
```

### Option C: Use a longer fence delimiter (4+ backticks)
- **Pros:** ``` inside a 4-backtick fence is not a closing delimiter
- **Cons:** Still breakable if input contains 4+ consecutive backticks (edge case)
- **Effort:** Small

```ruby
lines << "````ruby"
# ...
lines << "````"
```

## Recommended Action

Option A. Simple find-and-replace preserves readability for the LLM while eliminating the structural break.

## Technical Details

- **Affected file:** `lib/console_historian/analyzer.rb:93-96`

## Acceptance Criteria

- [x] Entry input containing ` ``` ` does not break Markdown code fence structure
- [x] Spec added: `format_log` with entry containing backtick shell expression
- [x] LLM prompt structure (headings, fences, metadata) remains intact for such entries

## Work Log

- 2026-05-29: Found by quality agent in /ce-review pass

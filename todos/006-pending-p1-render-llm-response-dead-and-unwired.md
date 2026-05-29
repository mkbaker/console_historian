---
name: render-llm-response-dead-and-unwired
description: Renderer#render_llm_response is dead code — never called in production path; LLM response used raw, bypassing any post-processing seam
metadata:
  type: finding
  priority: p1
  tags: [correctness, code-review]
---

## Problem Statement

`Renderer#render_llm_response` exists in the codebase, has a spec, and looks like part of the output pipeline. It is never called. `Recorder#finish` uses the LLM response directly:

```ruby
content = Analyzer.new.analyze(@entries, metadata)       # LLM text, used as-is
content ||= Renderer.new.render_fallback(...)            # fallback only
```

The intent appears to be `Analyzer → Renderer#render_llm_response → Storage`, but the middle step is skipped. The spec tests the method in isolation but no integration test catches that it is bypassed.

Additionally, `render_llm_response` takes `_stem` as a parameter (unused/ignored), which is a sign the API was designed for more but never implemented.

## Findings

**recorder.rb:96-99:**
```ruby
content = Analyzer.new.analyze(@entries, metadata)
content ||= Renderer.new.render_fallback(@stem, @entries, metadata)
# render_llm_response never called
```

**renderer.rb:5-7:**
```ruby
def render_llm_response(_stem, response_text)
  response_text.to_s.strip  # ← dead code path
end
```

**renderer_spec.rb:8-16:** Tests `render_llm_response` but the production path never calls it.

## Proposed Solutions

### Option A: Wire into finish path (Correct if keeping the class)
- **Pros:** Makes the seam real; future post-processing (strip LLM preamble, inject metadata) has a home
- **Cons:** Tiny behavior change (`.to_s.strip` is now applied; effectively no-op since analyze already returns clean text)
- **Effort:** Small

```ruby
# recorder.rb:96-99
raw = Analyzer.new.analyze(@entries, metadata)
content = raw ? Renderer.new.render_llm_response(@stem, raw) : nil
content ||= Renderer.new.render_fallback(@stem, @entries, metadata)
```

### Option B: Delete render_llm_response and its spec (Simplest)
- **Pros:** Removes dead code; fewer moving parts
- **Cons:** Loses the extension seam; if post-processing is ever needed, re-add it
- **Effort:** Small (delete method + spec examples)

### Option C: Inline into recorder, delete Renderer if only fallback remains
- **Pros:** Removes a class that exists only for one meaningful method
- **Cons:** Slightly less testable fallback rendering
- **Effort:** Small

## Recommended Action

Option A if post-processing is a likely future need. Option B otherwise. The spec must match whichever is chosen.

## Technical Details

- **Affected files:** `lib/console_historian/renderer.rb:5-7`, `lib/console_historian/recorder.rb:96-99`, `spec/console_historian/renderer_spec.rb:8-16`

## Acceptance Criteria

- [ ] Either `render_llm_response` is called in `Recorder#finish`, OR the method and its spec are deleted
- [ ] No production code path calls a method that has no test coverage and vice versa
- [ ] Renderer spec covers only methods that are actually called in production

## Work Log

- 2026-05-29: Found by simplicity and architecture agents in /ce-review pass

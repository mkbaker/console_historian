---
name: providers-no-shared-base
description: Three provider classes share call(system, user) interface and HTTP error handling with no base module — duplication and undocumented behavioral divergence
metadata:
  type: finding
  priority: p3
  tags: [architecture, code-review]
---

## Problem Statement

The three providers share a `call(system_prompt, user_content) → String` interface implicitly. They also duplicate the HTTP error check pattern. Ollama merges system+user with a newline while Anthropic/OpenAI use them as separate roles — this behavioral divergence is undocumented.

**Duplicated code across providers:**
```ruby
raise ProviderError, "... #{response.code}: #{response.body[0, 200]}" unless response.code.to_i == 200
```

## Findings

- `providers/anthropic.rb:37`
- `providers/openai.rb:37`
- `providers/ollama.rb:33`

All three implement identical raise pattern. Divergence: Ollama concatenates system+user (`"#{system_prompt}\n\n#{user_content}"`); Anthropic/OpenAI use them as separate API roles.

## Proposed Solutions

### Option A: Extract Providers::Base module with shared helpers
```ruby
module ConsoleHistorian
  module Providers
    module Base
      # Documents the contract
      # def call(system_prompt, user_content) = raise NotImplementedError

      private

      def raise_unless_200(response, provider_name)
        return if response.code.to_i == 200
        raise ProviderError, "#{provider_name} API #{response.code}: #{response.body[0, 200]}"
      end
    end
  end
end
```

### Option B: Leave as-is, add a comment documenting the interface
- Minimal; avoids over-engineering for 3 small classes
- **Effort:** Trivial

## Recommended Action

Option B short-term (add comment), Option A if a 4th provider is ever added.

## Technical Details

- **Affected files:** `lib/console_historian/providers/anthropic.rb`, `openai.rb`, `ollama.rb`

## Acceptance Criteria

- [x] Either a shared module exists with documented `call` interface, OR a comment in each provider documents the expected signature
- [x] Error-raising pattern deduplicated if base module added

## Work Log

- 2026-05-29: Found by architecture agent in /ce-review pass

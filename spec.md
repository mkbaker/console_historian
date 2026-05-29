# console_historian — Gem Specification

## Overview

`console_historian` is a Rails development gem that silently records every command entered during a `rails console` session, then uses an LLM to analyze the session and produce a human-readable runbook — a reusable guide to what you were investigating and how to get back there.

---

## Problem

Rails console sessions are ephemeral. Developers frequently investigate bugs, explore data, or prototype queries in the console, then lose that work when the session ends. There's no record of what was tried, what the findings were, or how to reproduce the investigation later. This forces teams to re-investigate the same issues and makes institutional knowledge fragile.

---

## Solution

Wrap the Rails console session transparently. On exit, send the command log to an LLM that reconstructs intent, summarizes findings, and produces a copy-paste runbook — saved to disk for future reference and team sharing.

---

## Goals

- Zero friction — works automatically once installed, no commands to remember
- Safe by default — redacts sensitive values before anything leaves the machine
- LLM-agnostic — works with Anthropic, OpenAI, Ollama (local), or not at all
- Output is plain Markdown — diffable, committable, grepable
- Development-only — no surface area in production

---

## Non-Goals

- Not a REPL replacement or debugger
- Not a database query logger (use `ActiveRecord::Base.logger` for that)
- Not a production monitoring tool
- Not a security audit trail

---

## Installation

```ruby
# Gemfile
gem 'console_historian', group: :development
```

```bash
bundle install
rails console_historian:install
```

---

## Install Generator

```bash
rails console_historian:install
```

This does two things:

1. Creates `config/initializers/console_historian.rb` with everything commented out and a pointer to the docs
2. Appends `log/console_sessions/` to `.gitignore` — but only after checking that neither `log/` nor `log/console_sessions/` is already covered. If `log/` is already ignored, the generator skips this step and notes it.

---

## Configuration

The install generator creates a minimal initializer. The only thing needed to get started is an API key in the environment — everything else has a sensible default.

```ruby
# config/initializers/console_historian.rb
# console_historian is ready to go.
# Set ANTHROPIC_API_KEY in your environment to enable AI analysis.
# See all config options: github.com/you/console_historian

# ConsoleHistorian.configure do |c|
#   c.ai_provider          = :anthropic   # :anthropic, :openai, :ollama, :none
#   c.save_path            = "log/console_sessions"
#   c.output_limit         = 500          # chars captured per command output
#   c.max_tokens_to_submit = 8_000        # total token budget for LLM submission
#   c.redact               = [:password, :token, :secret, :api_key, :ssn, :credit_card]
# end
```

**`output_limit`** caps characters captured per command output. Default is intentionally low (500) because output is a secondary signal — the commands are what matter.

**`max_tokens_to_submit`** is a hard ceiling on what gets sent to the LLM. If the assembled log exceeds this, per-command outputs are reduced further until it fits. Command inputs are never cut to meet this budget.

---

## Behavior

### During a session

The gem hooks into IRB via its native callback APIs. No monkey-patching. On session start, a single line is printed:

```
[historian] recording session › log/console_sessions/2026-05-29_14-14_abc1234.md
```

Each command is recorded as a single entry, including multi-line blocks. The recorder waits for IRB to signal input completion (i.e. the block or heredoc is closed) before the entry is finalized. Each entry captures:

- Sequence index and timestamp
- Raw input (full block, exactly as typed)
- Truncated output (see Output Truncation below)
- Return value class (e.g. `ActiveRecord::Relation`, `Integer`)
- Duration in milliseconds
- Exception class and message, if the command raised

Nothing is sent anywhere during the session. `ConsoleHistorian.session_id` returns the current session's filename stem and is available inside the running console.

### Output truncation

Output is a secondary signal — the developer's commands are what matter. Output is truncated aggressively:

**Per-command:** Output is truncated from the bottom — the first part of any response is what the developer actually reads. Two cases:

- **ActiveRecord object or collection:** capture the first record's `inspect` string in full, discard the rest, append a count: `[... 846 more records truncated]`. A single AR object inspect is the meaningful unit; everything after is noise.
- **Everything else (strings, primitives, hashes, arrays):** capture the first `output_limit` characters and append `[... N chars truncated]` if cut.

The return value class is always recorded separately (`Integer`, `ActiveRecord::Relation`, etc.) so the LLM has type signal even when the output itself is nearly empty.

**Pre-submission:** Before sending to the LLM, if the total assembled log exceeds `max_tokens_to_submit`, all per-command outputs are dropped entirely — only the input, return class, duration, and error (if any) are kept per command. Command inputs are never truncated or dropped under any circumstances. They are the record. The default `max_tokens_to_submit` of 8,000 is chosen with this priority in mind: a session of 50 commands with zero output fits comfortably; output is what pushes the log over budget.

### On exit

When the console exits (cleanly or via Ctrl+D):

1. The command log is assembled and redacted
2. If a provider is configured and an API key is present, the log is sent to the LLM
3. The LLM response is parsed and saved as a Markdown file in `save_path`
4. If the LLM call fails, is unconfigured, or the session had fewer than 3 commands, a fallback file is saved: a minimal no-LLM summary containing the session header and a clean list of input commands only (no output). This is still useful — it reads like an annotated shell history.
5. A single line is printed on exit:

```
[historian] saved › log/console_sessions/2026-05-29_14-14_abc1234.md
```

### File naming

```
log/console_sessions/2026-05-29_14-14_fix-order-shipping_abc1234.md
                      ^date  ^time  ^branch (sanitized, 30 chars max)  ^sha
```

Branch name characters that aren't alphanumeric are replaced with `-`. Git fields are omitted if the project isn't a git repo.

---

## Output Format

```markdown
# Console Session — 2026-05-29 14:14

**Git SHA:** abc1234  
**Duration:** 23 minutes  
**Commands:** 17

---

## What you were investigating

Why orders placed between May 1–3 had missing shipping labels.

## What you found

- 847 orders were affected, all associated with `carrier_id: 12` (FedEx staging account)
- `ShippingLabel.generate!` silently fails when the carrier record is in `:sandbox` mode
- No exception is raised; the label record is simply not created

## Key commands

```ruby
# Find affected orders
Order.where(created_at: may1..may3).where(shipping_label: nil).count
# => 847

# Confirm the carrier mode
Order.find(12345).shipping_label.carrier.mode
# => "sandbox"
```

## To reproduce this investigation

```ruby
may1 = Date.new(2026, 5, 1).beginning_of_day
may3 = Date.new(2026, 5, 3).end_of_day

affected = Order.where(created_at: may1..may3).where(shipping_label: nil)
affected.count
affected.first.carrier.mode
```

## Suggested next steps

- Check whether other carriers have sandbox-mode records in production
- Add a validation or guard in `ShippingLabel.generate!` for sandbox carriers
- Backfill labels for the 847 affected orders after fix is deployed
```

---

## CLI

A lightweight CLI is provided for working with saved sessions.

```bash
# List recent sessions
rails console_historian:list

# Print a session
rails console_historian:show 2026-05-29_14-14

# Re-analyze a session (e.g. after changing LLM provider)
rails console_historian:analyze 2026-05-29_14-14
```

---

## Redaction

Before any data is sent to an LLM:

- Values of attributes matching `c.redact` names are replaced with `[REDACTED]`
- This applies to both command inputs and captured outputs
- Redaction is conservative — partial matches are caught (e.g. `api_key`, `reset_password_token`)
- Raw (unredacted) logs are never saved to disk or transmitted

Redaction is best-effort. Users working with sensitive production data should use `:none` as the provider and review logs manually.

---

## LLM Prompt Design

The prompt sent to the LLM includes:

- A structured system prompt establishing the analysis task
- The redacted command log (inputs, outputs, timestamps)
- Instructions to produce the output in a specific Markdown schema

The gem owns the prompt entirely — users don't need to configure it.

---

## Privacy & Security Considerations

- The gem is `group: :development` only — zero production footprint
- No data is sent during the session, only on exit
- API keys are read from environment variables by default, never hardcoded
- Session files are local only — saved to `log/console_sessions/` on the developer's machine and should be added to `.gitignore`
- Users on sensitive projects should set `ai_provider: :none` to keep all data local; Ollama can be used for local LLM analysis

---

## Compatibility

| | Version |
|---|---|
| Ruby | >= 3.0 |
| Rails | >= 7.0 |
| IRB | >= 1.4 |

---

## Gem Structure

```
console_historian/
├── lib/
│   ├── console_historian.rb          # Entry point, configuration
│   ├── console_historian/
│   │   ├── recorder.rb               # IRB hooks, command capture, multi-line handling
│   │   ├── truncator.rb              # Per-command and total-log truncation
│   │   ├── redactor.rb               # Sensitive value scrubbing
│   │   ├── analyzer.rb               # LLM dispatch + prompt assembly
│   │   ├── renderer.rb               # Markdown output formatting
│   │   ├── storage.rb                # File save/load/list
│   │   └── providers/
│   │       └── anthropic.rb
├── railtie.rb                        # Rails integration, CLI tasks
└── spec/                             # RSpec test suite
```

---

## Decisions

| Topic | Decision |
|---|---|
| Output truncation | Two-stage: truncate per-command from the bottom (first X chars or first ActiveRecord object only), then cap total log before LLM submission. Commands are the priority — output is heavily truncated. |
| Multi-line input | Entire block (do...end, heredoc, etc.) is recorded as a single command. Recorder waits for IRB to signal input completion before closing the entry. |
| Session identity | One open console process = one session, regardless of idle time. Variables persist across the session so splitting on inactivity would break context. |
| Session ID | Exposed at runtime via `ConsoleHistorian.session_id` for use inside a running console |
| Pry support | Out of scope — IRB only |
| Session storage | Local only — `log/console_sessions/` on the developer's machine, never committed |
| Terminal output | Two lines only: one on session start, one on exit confirming where the file was saved |
| Session naming | Stretch goal, not in MVP |

## Stretch Goals

- **Session naming** — annotate mid-session with a name or note to improve file organization (e.g. `historian note: investigating order 12345`)
- **Streaming** — stream the LLM response to the terminal on exit rather than a silent pause
- **CLI search** — keyword or semantic search across saved sessions

# ConsoleHistorian

Records Rails console sessions and generates LLM-powered runbooks.

Add this line to your application's **Gemfile**:

```ruby
gem "console_historian", group: :development
```

Run:

```sh
bundle install
rails console_historian:install
```

The install generator creates `config/initializers/console_historian.rb` and appends `log/console_sessions/` to `.gitignore`.

## Configuration

```ruby
# config/initializers/console_historian.rb
# Set ANTHROPIC_API_KEY in your environment to enable AI analysis.

# ConsoleHistorian.configure do |c|
#   c.ai_provider          = :anthropic   # :anthropic, :openai, :ollama, :none
#   c.save_path            = "log/console_sessions"
#   c.output_limit         = 500
#   c.max_tokens_to_submit = 8_000
#   c.redact               = [:password, :token, :secret, :api_key, :ssn, :credit_card]
# end
```

## Usage

Start a console session normally:

```sh
rails console
```

ConsoleHistorian hooks into IRB automatically. It prints a single line on start:

```
[historian] recording session › log/console_sessions/2026-05-29_14-14_fix-order-shipping_abc1234.md
```

Run commands as usual. Nothing is sent to an LLM during the session.

On exit, ConsoleHistorian redacts sensitive values, submits the session to the configured LLM, and saves a Markdown runbook:

```
[historian] saved › log/console_sessions/2026-05-29_14-14_fix-order-shipping_abc1234.md
```

If no LLM is configured, the session has fewer than 3 commands, or the LLM call fails, a minimal summary with the command list is saved instead.

## Output

Each runbook follows this structure:

```markdown
# Console Session — 2026-05-29 14:14

**Git SHA:** abc1234
**Duration:** 23 minutes
**Commands:** 17

---

## What you were investigating
Why orders placed between May 1–3 had missing shipping labels.

## What you found
- 847 orders were affected...

## Key commands
...

## To reproduce this investigation
...

## Suggested next steps
...
```

Session files are named by date, time, sanitized branch name (max 30 chars), and git SHA:

```
log/console_sessions/2026-05-29_14-14_fix-order-shipping_abc1234.md
```

## CLI

List saved sessions:

```sh
rails console_historian:list
```

Show a session:

```sh
rails console_historian:show 2026-05-29_14-14
```

Re-analyze a session with the LLM:

```sh
rails console_historian:analyze 2026-05-29_14-14
```

## Redaction

Values matching the `redact` list are replaced with `[REDACTED]` in both inputs and outputs before saving or transmitting. Partial matches are caught — for example, `api_key` and `reset_password_token` both match.

Raw session data is never written to disk or transmitted.

## Security

- Use `group: :development` — zero production footprint
- API keys are read from environment variables only
- Session files stay local; keep them in `.gitignore`
- Use `ai_provider: :none` with a local Ollama instance for fully offline analysis

## Compatibility

- Ruby >= 3.0
- Rails >= 7.0
- IRB >= 1.4

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/mkbaker/console_historian](https://github.com/mkbaker/console_historian).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

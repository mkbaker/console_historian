# frozen_string_literal: true

module ConsoleHistorian
  class Analyzer
    SYSTEM_PROMPT = <<~PROMPT
      You are analyzing a Rails console session. The developer was exploring, debugging, or investigating something.
      Reconstruct their intent and produce a runbook in exactly this Markdown format:

      # Console Session — {DATE}

      **Git SHA:** {SHA}
      **Duration:** {N} minutes
      **Commands:** {N}

      ---

      ## What you were investigating

      {one sentence describing the investigation}

      ## What you found

      - {finding 1}
      - {finding 2}

      ## Key commands

      ```ruby
      # {comment explaining what this does}
      {command}
      # => {result}
      ```

      ## To reproduce this investigation

      ```ruby
      {clean, copy-paste ready reproduction steps}
      ```

      ## Suggested next steps

      - {next step 1}
      - {next step 2}

      Output only the Markdown. No preamble, no explanation.
    PROMPT

    def initialize(config = nil)
      @config = config || ConsoleHistorian.configuration
    end

    def analyze(entries, metadata = {})
      return nil if entries.length < 3
      return nil if @config.ai_provider == :none

      provider = build_provider
      return nil if provider.nil?

      redacted = Redactor.new.redact_entries(entries)
      trimmed = Truncator.new.pre_submission(redacted)
      user_content = format_log(trimmed, metadata)

      provider.call(SYSTEM_PROMPT, user_content)
    rescue ProviderError, StandardError => e
      warn "[historian] AI analysis failed (#{e.class}): #{e.message}"
      nil
    end

    private

    def build_provider
      case @config.ai_provider
      when :anthropic
        key = ENV["ANTHROPIC_API_KEY"]
        return nil if key.nil? || key.empty?

        Providers::Anthropic.new
      when :openai
        key = ENV["OPENAI_API_KEY"]
        return nil if key.nil? || key.empty?

        Providers::OpenAI.new
      when :ollama
        Providers::Ollama.new
      end
    end

    def format_log(entries, metadata)
      lines = ["Session started: #{metadata[:started_at]}", ""]
      entries.each_with_index do |entry, i|
        lines << "### Command #{i + 1} (#{entry[:timestamp]})"
        lines << "```ruby"
        lines << entry[:input].to_s.gsub("```", "'''")
        lines << "```"
        if entry[:error]
          lines << "**Error:** #{entry[:error_class]}: #{entry[:error]}"
        elsif !entry[:output].to_s.empty?
          lines << "Output: #{entry[:output]}"
        end
        lines << "Return type: #{entry[:return_class]}" if entry[:return_class]
        lines << "Duration: #{entry[:duration_ms]}ms" if entry[:duration_ms]
        lines << ""
      end
      lines.join("\n")
    end
  end
end

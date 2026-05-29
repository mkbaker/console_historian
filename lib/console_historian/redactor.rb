# frozen_string_literal: true

module ConsoleHistorian
  class Redactor
    REDACTED = "[REDACTED]"

    def initialize(patterns = nil)
      @patterns = patterns || ConsoleHistorian.configuration.redact
      @compiled = @patterns.map do |pattern|
        pat = Regexp.escape(pattern.to_s)
        /(\b#{pat}\b\s*(?:=>|:)\s*)(?:"[^"]*"|'[^']*'|\S+)/i
      end
    end

    def redact(text)
      return text unless text.is_a?(String)

      @compiled.each do |regex|
        text = text.gsub(regex) { "#{Regexp.last_match(1)}#{REDACTED}" }
      end
      text
    end

    def redact_entries(entries)
      entries.map do |entry|
        entry.merge(
          input: redact(entry[:input].to_s),
          output: redact(entry[:output].to_s)
        )
      end
    end
  end
end

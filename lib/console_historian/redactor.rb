# frozen_string_literal: true

module ConsoleHistorian
  class Redactor
    REDACTED = "[REDACTED]"

    def initialize(patterns = nil)
      @patterns = patterns || ConsoleHistorian.configuration.redact
    end

    def redact(text)
      return text unless text.is_a?(String)

      @patterns.each do |pattern|
        pat = Regexp.escape(pattern.to_s)
        # Captures key+separator as group 1, replaces the value with [REDACTED].
        # Handles: key: "val", key: val, key => "val", key => val
        text = text.gsub(/(\b#{pat}\b\s*(?:=>|:)\s*)(?:"[^"]*"|'[^']*'|\S+)/i) do
          "#{Regexp.last_match(1)}#{REDACTED}"
        end
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

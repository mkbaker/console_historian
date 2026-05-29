# frozen_string_literal: true

module ConsoleHistorian
  class Truncator
    AR_INSPECT_PATTERN = /\A#<(?:ActiveRecord::|[A-Z][A-Za-z:]*(?:Record|Model))/

    def initialize(config = nil)
      @config = config || ConsoleHistorian.configuration
    end

    def truncate_output(output, return_class = nil)
      return '' if output.nil? || output.empty?

      if ar_type?(return_class, output)
        truncate_ar(output)
      else
        truncate_generic(output)
      end
    end

    # Drop all outputs if total log exceeds token budget. Commands are never dropped.
    def pre_submission(entries)
      total_chars = entries.sum { |e| e[:input].to_s.length + e[:output].to_s.length }
      # rough 4-chars-per-token estimate
      return entries if total_chars <= @config.max_tokens_to_submit * 4

      entries.map { |e| e.merge(output: '', pre_submission_truncated: true) }
    end

    private

    def ar_type?(return_class, output)
      return true if return_class.to_s.include?('ActiveRecord') || return_class.to_s.include?('Relation')

      output.match?(AR_INSPECT_PATTERN)
    end

    def truncate_ar(output)
      boundary = find_first_record_end(output)
      if boundary
        first = output[0, boundary + 1]
        rest = output[(boundary + 1)..]
        rest.to_s.strip.empty? ? first : "#{first}\n[... more records truncated]"
      else
        truncate_generic(output)
      end
    end

    def find_first_record_end(output)
      depth = 0
      in_string = false
      escape_next = false
      output.each_char.with_index do |ch, i|
        if escape_next
          escape_next = false
          next
        end
        if in_string
          escape_next = true if ch == '\\'
          in_string = false if ch == '"'
          next
        end
        case ch
        when '"' then in_string = true
        when '<' then depth += 1
        when '>'
          depth -= 1
          return i if depth.zero?
        end
      end
      nil
    end

    def truncate_generic(output)
      limit = @config.output_limit
      return output if output.length <= limit

      "#{output[0, limit]}[... #{output.length - limit} chars truncated]"
    end
  end
end

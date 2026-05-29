# frozen_string_literal: true

module ConsoleHistorian
  class Renderer
    def render_llm_response(_stem, response_text)
      response_text.to_s.strip
    end

    def render_fallback(stem, entries, metadata = {})
      lines = []
      started = metadata[:started_at] || stem
      lines << "# Console Session — #{started}"
      lines << ""

      lines << "**Git SHA:** #{metadata[:git_sha]}  " if metadata[:git_sha]
      lines << "**Duration:** #{metadata[:duration_minutes]} minutes  " if metadata[:duration_minutes]
      lines << "**Commands:** #{entries.length}"
      lines << ""
      lines << "---"
      lines << ""
      lines << "## Commands"
      lines << ""
      lines << "```ruby"
      entries.each { |e| lines << e[:input].to_s.strip }
      lines << "```"

      lines.join("\n")
    end
  end
end

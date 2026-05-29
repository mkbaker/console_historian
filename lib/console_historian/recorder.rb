# frozen_string_literal: true

require 'time'

module ConsoleHistorian
  # Prepended onto IRB::Context to intercept per-command evaluate calls.
  # evaluate(line, line_no) is called once per complete statement (including multi-line blocks).
  module IRBContextHook
    def evaluate(line, line_no, exception: nil)
      recorder = ConsoleHistorian.current_recorder
      return super unless recorder&.recording?
      return super if line.nil? || line.strip.empty?

      start_ms = (Time.now.to_f * 1000).to_i

      begin
        result = super
        duration_ms = (Time.now.to_f * 1000).to_i - start_ms
        output = begin
          last_value.inspect
        rescue StandardError
          ''
        end
        return_class = begin
          last_value.class.name
        rescue StandardError
          nil
        end
        recorder.record_command(
          input: line.to_s.strip,
          output: Truncator.new.truncate_output(output, return_class),
          return_class: return_class,
          duration_ms: duration_ms,
          timestamp: Time.now.iso8601
        )
        result
      rescue StandardError => e
        duration_ms = (Time.now.to_f * 1000).to_i - start_ms
        recorder.record_command(
          input: line.to_s.strip,
          output: '',
          error: e.message,
          error_class: e.class.name,
          duration_ms: duration_ms,
          timestamp: Time.now.iso8601
        )
        raise
      end
    end
  end

  class Recorder
    def self.start
      recorder = new
      recorder.begin_session
      recorder
    end

    def begin_session
      @entries = []
      @started_at = Time.now
      @stem = generate_stem
      @recording = true
      @finished = false

      ConsoleHistorian.instance_variable_set(:@current_recorder, self)
      ConsoleHistorian.instance_variable_set(:@session_id, @stem)

      hook_irb
      unless self.class.instance_variable_get(:@exit_registered)
        self.class.instance_variable_set(:@exit_registered, true)
        at_exit { ConsoleHistorian.current_recorder&.finish }
      end

      puts "[historian] recording session › #{Storage.new.file_path(@stem)}"
      return unless ConsoleHistorian.configuration.redact.any?

      puts '[historian] note: redaction is keyword-proximity only — raw output values (e.g. User.first.password) are not scrubbed'
    end

    def recording?
      @recording
    end

    def record_command(entry)
      @entries << entry
    end

    def finish
      return if @finished

      @finished = true
      @recording = false

      duration_minutes = ((Time.now - @started_at) / 60).round
      metadata = {
        started_at: @started_at.strftime('%Y-%m-%d %H:%M'),
        git_sha: git_sha,
        duration_minutes: duration_minutes
      }

      raw = Analyzer.new.analyze(@entries, metadata)
      content = raw ? Renderer.new.render_llm_response(@stem, raw) : nil
      content ||= Renderer.new.render_fallback(@stem, @entries, metadata)

      path = Storage.new.save(@stem, content)
      puts "[historian] saved › #{path}"
    rescue StandardError => e
      warn "[historian] error saving session: #{e.message}"
    end

    private

    def hook_irb
      return unless defined?(IRB::Context)
      return if IRB::Context.ancestors.include?(IRBContextHook)

      IRB::Context.prepend(IRBContextHook)
    end

    def generate_stem
      time_part = @started_at.strftime('%Y-%m-%d_%H-%M')
      branch_part = sanitize_branch(current_branch)
      sha_part = git_sha
      [time_part, branch_part, sha_part].compact.reject(&:empty?).join('_')
    end

    def current_branch
      out = `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
      out.empty? ? nil : out[0, 30]
    rescue StandardError
      nil
    end

    def git_sha
      out = `git rev-parse --short HEAD 2>/dev/null`.strip
      out.empty? ? nil : out
    rescue StandardError
      nil
    end

    def sanitize_branch(branch)
      return nil if branch.nil? || branch.empty?

      branch.gsub(/[^a-zA-Z0-9]/, '-').gsub(/-{2,}/, '-').gsub(/\A-|-\z/, '')[0, 30]
    end
  end
end

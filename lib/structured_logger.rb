# frozen_string_literal: true

require "time"

class StructuredLogger
  def initialize(io = $stdout)
    @io = io
    @mutex = Mutex.new
    @thread_ids = {}
    @last_progress_length = 0
  end

  def info(message, context = {})
    log("INFO", message, context)
  end

  def error(message, context = {})
    log("ERROR", message, context)
  end

  def warn(message, context = {})
    log("WARN", message, context)
  end

  def progress(message, context = {})
    log("PROGRESS", message, context)
  end

  def snapshot(message, context = {})
    log("SNAPSHOT", message, context)
  end

  private

  def log(level, message, context)
    # Silent mode - skip all logging if io is nil
    return if @io.nil?

    # Pre-calculate thread ID outside mutex for efficiency
    current_thread = Thread.current
    thread_id = @thread_ids[current_thread] ||= current_thread.object_id.to_s(16).rjust(4, "0")[-4..]

    @mutex.synchronize do
      timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")

      parts = ["[#{timestamp}]", "[#{level}]", "[Thread:#{thread_id}]"]

      # Add repository context if available
      parts << "[#{context[:repo]}]" if context[:repo]

      # Add worker context if available
      parts << "[Worker:#{context[:worker_id]}]" if context[:worker_id]

      formatted_message = "#{parts.join(" ")} #{message}"

      if level == "PROGRESS"
        # Clear previous progress line if it was longer
        if @last_progress_length > formatted_message.length
          @io.print "\r#{" " * @last_progress_length}\r"
        end
        @io.print "\r#{formatted_message}"
        @last_progress_length = formatted_message.length
        @io.flush
      else
        # Clear any lingering progress line
        if @last_progress_length > 0
          @io.print "\r#{" " * @last_progress_length}\r"
          @last_progress_length = 0
        end
        @io.puts formatted_message
      end
    end
  end
end

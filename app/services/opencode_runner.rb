# frozen_string_literal: true

require "open3"
require "tmpdir"

# Sends one prompt to a model through the `opencode run` CLI and reports what it
# cost. This is the only way to reach Zen's free chat models: their API refuses
# requests that do not come from OpenCode itself.
#
# The numbers include OpenCode's own overhead. Every run carries its system prompt
# and tool definitions as input tokens, and the wall time includes starting the CLI.
# TriageBenchmark measures that overhead with a trivial prompt and reports it.
class OpencodeRunner
  def self.bin = ENV.fetch("OPENCODE_BIN", File.expand_path("~/.opencode/bin/opencode"))

  attr_reader :model, :timeout

  def initialize(model:, timeout: 120)
    @model = model
    @timeout = timeout
  end

  def run(prompt)
    # An empty directory, so OpenCode does not pick up this app as project context.
    Dir.mktmpdir("triage-benchmark") do |dir|
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      stdout, stderr, status = Open3.capture3(
        "timeout", timeout.to_s, self.class.bin, "run", "-m", model, "--format", "json", prompt,
        chdir: dir, stdin_data: ""
      )
      wall_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

      parse(stdout, wall_ms:, error: status.success? ? nil : "exit #{status.exitstatus}: #{stderr.lines.last(3).join.strip}")
    end
  end

  private

  def parse(stdout, wall_ms:, error:)
    events = stdout.each_line.filter_map do |line|
      JSON.parse(line)
    rescue JSON::ParserError
      nil
    end

    finishes = events.select { |event| event["type"] == "step_finish" }
    starts = events.select { |event| event["type"] == "step_start" }
    tokens = finishes.map { |event| event.dig("part", "tokens") || {} }
    error ||= events.find { |event| event["type"] == "error" }&.then { |event| event.dig("error", "message") || event.to_json }
    error ||= "no step_finish in output" if finishes.empty?

    LlmRun.new(
      text: events.select { |event| event["type"] == "text" }.map { |event| event.dig("part", "text") }.join,
      input_tokens: tokens.sum { |t| t["input"].to_i + t.dig("cache", "read").to_i },
      output_tokens: tokens.sum { |t| t["output"].to_i },
      reasoning_tokens: tokens.sum { |t| t["reasoning"].to_i },
      wall_ms: wall_ms,
      model_ms: starts.any? && finishes.any? ? finishes.last["timestamp"] - starts.first["timestamp"] : nil,
      error: error
    )
  end
end

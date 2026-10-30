# frozen_string_literal: true

require "net/http"

# Sends one prompt to an OpenAI model through the Chat Completions API, asking for
# a JSON object back. Reads OPENAI_API_KEY from the environment.
class OpenaiRunner
  ENDPOINT = URI("https://api.openai.com/v1/chat/completions")

  attr_reader :model, :reasoning_effort, :timeout

  # reasoning_effort -- "minimal", "low", "medium" or "high"; nil leaves the API
  #                     default (medium for GPT-5).
  def initialize(model:, reasoning_effort: nil, timeout: 120)
    @model = model
    @reasoning_effort = reasoning_effort
    @timeout = timeout
  end

  def run(prompt)
    body = { model: model, response_format: { type: "json_object" }, messages: [ { role: "user", content: prompt } ] }
    body[:reasoning_effort] = reasoning_effort if reasoning_effort

    request = Net::HTTP::Post.new(ENDPOINT)
    request["Authorization"] = "Bearer #{ENV.fetch("OPENAI_API_KEY")}"
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 10, read_timeout: timeout) do |http|
      http.request(request)
    end
    wall_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

    parse(response, wall_ms)
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => e
    failure("#{e.class}: #{e.message}")
  end

  private

  def parse(response, wall_ms)
    data = JSON.parse(response.body)
    return failure("HTTP #{response.code}: #{data.dig("error", "message")}", wall_ms) unless response.is_a?(Net::HTTPSuccess)

    usage = data["usage"] || {}
    reasoning = usage.dig("completion_tokens_details", "reasoning_tokens").to_i

    LlmRun.new(
      text: data.dig("choices", 0, "message", "content").to_s,
      input_tokens: usage["prompt_tokens"].to_i,
      output_tokens: usage["completion_tokens"].to_i - reasoning,
      reasoning_tokens: reasoning,
      wall_ms: wall_ms,
      # The API reports no server-side timing, so the round trip is the best figure.
      model_ms: wall_ms,
      error: nil
    )
  rescue JSON::ParserError
    failure("HTTP #{response.code}: response was not JSON", wall_ms)
  end

  def failure(message, wall_ms = nil)
    LlmRun.new(text: "", input_tokens: 0, output_tokens: 0, reasoning_tokens: 0, wall_ms: wall_ms, model_ms: nil, error: message)
  end
end

# frozen_string_literal: true

Jevalyn.configure do |c|
  # Jev is served through OpenCode Zen, which speaks the same /v1/systemone API as
  # TypeSafe, so the gem only needs a different host and key. Keep the key in .env.
  c.api_key = ENV["OPENCODE_API_KEY"]
  c.base_url = "https://opencode.ai/zen"

  # The free tier on Zen. It is a pinned version, not an alias, so thresholds tuned
  # against it stay valid. Every Result reports the version that actually answered.
  c.default_model = "jev-1.13-free"

  # Jev answers in well under a second. A long timeout only means a slow request
  # holds a Rails thread open for longer than it is worth.
  c.timeout = 10
  c.open_timeout = 5

  # 429 (rate limited) and 529 (overloaded) are retried with exponential backoff,
  # honouring the API's retry-after header when it sends one.
  c.max_retries = 2

  # No network in tests. Answers come from Jevalyn::Testing stubs instead; an
  # unstubbed evaluation raises rather than silently passing.
  c.mock_mode = Rails.env.test?

  # Certainty floor a Decision uses when it does not declare its own. Leave nil to
  # require each Decision to make its own call, which is usually the right default:
  # the threshold for routing a support ticket is not the threshold for a refund.
  # c.default_confidence_threshold = 0.75
end

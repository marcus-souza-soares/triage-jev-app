# frozen_string_literal: true

# One prompt sent to a general-purpose LLM, and what it cost. Returned by
# OpenaiRunner and OpencodeRunner so TriageBenchmark can treat them alike.
#
# output_tokens excludes reasoning_tokens; add them for everything the model wrote.
LlmRun = Data.define(:text, :input_tokens, :output_tokens, :reasoning_tokens, :wall_ms, :model_ms, :error) do
  def ok? = error.nil?
end

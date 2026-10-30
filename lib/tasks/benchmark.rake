namespace :benchmark do
  desc "Triage the sample tickets with Jev and with an LLM. LLM=opencode/<model> (default glm-5.3-flash-free) or openai/<model>; REASONING=minimal|low|medium|high for OpenAI."
  task triage: :environment do
    run = TriageBenchmark.run!(llm_model: ENV.fetch("LLM", TriageBenchmark::DEFAULT_LLM), reasoning_effort: ENV["REASONING"].presence)
    puts "Done: /benchmarks/#{run.id}"
  end
end

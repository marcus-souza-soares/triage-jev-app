# frozen_string_literal: true

# Triages the same tickets with Jev (SupportTriage) and with a general-purpose LLM,
# and records latency, tokens and agreement with an expected answer for each.
# Run it with `bin/rails benchmark:triage`.
#
# The LLM is named "provider/model": "openai/gpt-5" goes straight to the OpenAI
# API; "opencode/<model>" goes through the opencode CLI, which adds its own system
# prompt to every call, so that overhead is measured and reported separately.
#
# Both sides get the same rubric: the LLM prompt is built from SupportTriage's own
# questions, so a change there changes both.
class TriageBenchmark
  DEFAULT_LLM = "opencode/glm-5.3-flash-free"

  # Hand-labelled. "Agreement" on the results page means agreement with these.
  SAMPLES = [
    { body: "O checkout está fora do ar para todos os clientes desde as 9h. Estamos perdendo vendas agora!",
      department: "technical", urgent: true, severity: "critical" },
    { body: "Fui cobrado duas vezes na fatura de outubro. Podem estornar uma das cobranças?",
      department: "billing", urgent: false, severity: "minor" },
    { body: "Quanto custa o plano Enterprise para 200 usuários? Queremos fechar ainda este trimestre.",
      department: "sales", urgent: false, severity: "trivial" },
    { body: "A integração com o Stripe parou de enviar webhooks desde ontem à noite. Os pedidos não estão sendo confirmados.",
      department: "technical", urgent: true, severity: "major" },
    { body: "Meu cartão foi recusado na renovação e a conta vai ser bloqueada amanhã. Preciso resolver hoje.",
      department: "billing", urgent: true, severity: "major" },
    { body: "O botão de exportar CSV está desalinhado no Safari. Não é nada grave, só avisando.",
      department: "technical", urgent: false, severity: "trivial" },
    { body: "Gostaria de fazer upgrade do plano Básico para o Pro. Como funciona a cobrança proporcional?",
      department: "sales", urgent: false, severity: "trivial" },
    { body: "Vazamento de dados? Um cliente diz que viu pedidos de outra empresa no painel dele. Isso é sério, respondam rápido.",
      department: "technical", urgent: true, severity: "critical" },
    { body: "Preciso da nota fiscal de setembro com o CNPJ atualizado para o fechamento contábil.",
      department: "billing", urgent: false, severity: "minor" },
    { body: "Os relatórios estão demorando uns 30 segundos para carregar. Dá para usar, mas está lento.",
      department: "technical", urgent: false, severity: "minor" }
  ].freeze

  # What OpenCode adds to every call before the ticket is even in the prompt.
  BASELINE_PROMPT = "Reply with exactly: ok"

  def self.run!(llm_model: DEFAULT_LLM, reasoning_effort: nil, samples: SAMPLES, log: $stdout)
    new(llm_model:, reasoning_effort:, log:).run!(samples)
  end

  def initialize(llm_model:, reasoning_effort:, log:)
    @llm_model = llm_model
    @reasoning_effort = reasoning_effort
    @llm = runner_for(llm_model)
    @log = log
  end

  def run!(samples)
    baseline = measure_baseline

    results = samples.each_with_index.map do |sample, index|
      say "[#{index + 1}/#{samples.size}] #{sample[:body].truncate(60)}"
      { "body" => sample[:body], "expected" => sample.slice(:department, :urgent, :severity).stringify_keys,
        "jev" => run_jev(sample), "llm" => run_llm(sample, baseline) }
    end

    BenchmarkRun.create!(
      llm_model: @llm_model,
      jev_model: Jevalyn.config.default_model,
      results: results,
      summary: {
        "jev" => summarize(results.map { |r| r["jev"] }),
        "llm" => summarize(results.map { |r| r["llm"] }),
        "llm_options" => { "reasoning_effort" => @reasoning_effort }.compact,
        "baseline" => baseline && { "input_tokens" => baseline.input_tokens, "output_tokens" => baseline.output_tokens,
                                    "wall_ms" => baseline.wall_ms, "model_ms" => baseline.model_ms }
      }
    )
  end

  private

  def runner_for(name)
    provider, model = name.split("/", 2)

    case provider
    when "openai" then OpenaiRunner.new(model:, reasoning_effort: @reasoning_effort)
    when "opencode" then OpencodeRunner.new(model: name)
    else raise ArgumentError, "Unknown LLM provider in #{name.inspect}. Use openai/<model> or opencode/<model>."
    end
  end

  # Only opencode adds a fixed prompt worth subtracting; a direct API call has none.
  def measure_baseline
    return nil unless @llm.is_a?(OpencodeRunner)

    say "Baseline do opencode (#{@llm_model})…"
    @llm.run(BASELINE_PROMPT).tap do |baseline|
      raise "opencode baseline failed: #{baseline.error}" unless baseline.ok?
    end
  end

  def run_jev(sample)
    started = clock
    result = SupportTriage.evaluate(sample[:body])
    wall_ms = elapsed_ms(started)
    prediction = { "department" => result.department.to_s, "urgent" => result.urgent?, "severity" => result.severity_label }

    { "ok" => true, "wall_ms" => wall_ms, "model_ms" => wall_ms,
      "input_tokens" => result.input_tokens, "output_tokens" => result.output_tokens, "reasoning_tokens" => 0,
      "prediction" => prediction, "matches" => matches(sample, prediction) }
  rescue Jevalyn::Error => e
    { "ok" => false, "error" => "#{e.class}: #{e.message}" }
  end

  def run_llm(sample, baseline)
    run = @llm.run(llm_prompt(sample[:body]))
    return { "ok" => false, "error" => run.error, "wall_ms" => run.wall_ms } unless run.ok?

    prediction = parse_prediction(run.text)
    { "ok" => true, "wall_ms" => run.wall_ms, "model_ms" => run.model_ms,
      "input_tokens" => run.input_tokens, "net_input_tokens" => baseline ? [ run.input_tokens - baseline.input_tokens, 0 ].max : run.input_tokens,
      "output_tokens" => run.output_tokens, "reasoning_tokens" => run.reasoning_tokens,
      "raw" => run.text.strip.truncate(500),
      "prediction" => prediction, "matches" => prediction && matches(sample, prediction) }
  end

  def llm_prompt(body)
    rubric = SupportTriage.questions.map do |name, question|
      options = case question.type
                when :noul then "true or false. true = #{question.criteria[:true]}; false = #{question.criteria[:false]}"
                when :choice then "one of: " + question.criteria.map { |key, text| "#{key} (#{text})" }.join(", ")
                when :score then "one of, lowest to highest: #{question.levels.join(", ")}"
                end
      "- #{name}: #{question.instructions} Answer #{options}."
    end

    <<~PROMPT
      Classify the support ticket below. Do not use any tools.
      Reply with a single JSON object and nothing else, no prose and no code fences:
      {"urgent": true|false, "department": "...", "severity": "..."}

      #{rubric.join("\n")}

      Ticket:
      #{body}
    PROMPT
  end

  def parse_prediction(text)
    json = text[/\{.*\}/m] or return nil
    data = JSON.parse(json)
    { "department" => data["department"].to_s, "urgent" => [ true, "true" ].include?(data["urgent"]),
      "severity" => data["severity"].to_s }
  rescue JSON::ParserError
    nil
  end

  def matches(sample, prediction)
    %w[department urgent severity].to_h { |key| [ key, prediction[key] == sample[key.to_sym] ] }
  end

  def summarize(runs)
    ok = runs.select { |run| run["ok"] }
    walls = ok.map { |run| run["wall_ms"] }.sort
    scored = ok.select { |run| run["matches"] }

    {
      "runs" => runs.size,
      "failures" => runs.size - ok.size,
      "avg_wall_ms" => average(walls),
      "p50_wall_ms" => walls[walls.size / 2],
      "max_wall_ms" => walls.last,
      "avg_model_ms" => average(ok.filter_map { |run| run["model_ms"] }),
      "avg_input_tokens" => average(ok.map { |run| run["input_tokens"] }),
      "avg_net_input_tokens" => average(ok.map { |run| run["net_input_tokens"] || run["input_tokens"] }),
      "avg_output_tokens" => average(ok.map { |run| run["output_tokens"].to_i + run["reasoning_tokens"].to_i }),
      "total_tokens" => ok.sum { |run| run["input_tokens"].to_i + run["output_tokens"].to_i + run["reasoning_tokens"].to_i },
      "unparsed" => ok.count { |run| run["prediction"].nil? },
      "agreement" => %w[department urgent severity].to_h do |key|
        [ key, scored.empty? ? nil : (scored.count { |run| run["matches"][key] } / scored.size.to_f).round(3) ]
      end
    }
  end

  def average(values)
    values.empty? ? nil : (values.sum / values.size.to_f).round(1)
  end

  def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def elapsed_ms(started) = ((clock - started) * 1000).round

  def say(message)
    @log&.puts(message)
  end
end

class Ticket < ApplicationRecord
  # Stricter floors the form can ask for, on top of the per-question defaults
  # declared in SupportTriage.
  STRICTNESS_LEVELS = [ 0.9, 0.95 ].freeze

  PER_PAGE = 20

  validates :body, presence: true

  # id breaks ties, so tickets created in the same instant keep a stable order
  # across pages.
  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :page, ->(number) { limit(PER_PAGE).offset((number - 1) * PER_PAGE) }

  def self.page_count
    [ (count / PER_PAGE.to_f).ceil, 1 ].max
  end

  # Runs SupportTriage on the body and keeps the answers alongside it, so the
  # ticket still shows what Jev said even after the rubric or the model changes.
  #
  # confidence_threshold -- one floor for every question, or nil to use the
  #                         per-question floors SupportTriage declares.
  def self.triage!(body, confidence_threshold: nil)
    options = confidence_threshold ? { confidence_threshold: confidence_threshold } : {}
    result = SupportTriage.evaluate(body, **options)

    create!(
      body: body,
      department: result.department,
      department_confidence: result.department_confidence,
      urgent: result.urgent?,
      urgency: result.urgent,
      severity: result.severity_label,
      severity_score: result.severity,
      certain: result.certain?,
      answered_by: result.model,
      analysis: analysis_for(body, result, confidence_threshold)
    )
  end

  # Everything the console shows about a Result, flattened into JSON: each
  # answer's distribution, confidence, floor and margin, plus what was sent.
  def self.analysis_for(body, result, confidence_threshold)
    margins = result.certainty_margins

    # Result#to_h is its own `values`, so build the Hash through Enumerable#map.
    questions = result.map do |name, answer|
      [ name.to_s, {
        "type" => answer.type.to_s,
        "value" => answer.value.is_a?(Symbol) ? answer.value.to_s : answer.value,
        "probabilities" => labelled_probabilities(answer),
        "confidence" => answer.confidence,
        "certainty" => answer.certainty,
        "threshold" => result.threshold_for(name),
        "margin" => margins[name],
        "certain" => result.certain_for?(name)
      } ]
    end.to_h

    {
      "questions" => questions,
      "uncertain_questions" => result.uncertain_questions.map(&:to_s),
      "confidence_threshold" => confidence_threshold,
      "input_tokens" => result.input_tokens,
      "output_tokens" => result.output_tokens,
      "estimated_tokens" => SupportTriage.estimated_tokens(body),
      "payload" => SupportTriage.payload_for(body)
    }
  end

  # A Score keys its distribution by level index; swap those for the level names.
  def self.labelled_probabilities(answer)
    return answer.probabilities unless answer.type == :score

    answer.probabilities.transform_keys { |level| answer.legend.fetch(level, level) }
  end
  private_class_method :labelled_probabilities

  def analysis_questions
    analysis.to_h.fetch("questions", {})
  end
end

# frozen_string_literal: true

# Ad-hoc questions to Jev, for when a full Jevalyn::Decision class is overkill:
# the console, a one-off script, a question you are still shaping. Host, key and
# model come from config/initializers/jevalyn.rb, and so do timeouts and retries.
#
#   result = JevClient.decide(
#     state: "My invoice was charged twice",
#     questions: {
#       refund: { type: :noul, instructions: "Is the customer asking for money back?",
#                 criteria: { true: "Asks for a refund", false: "Does not" } }
#     }
#   )
#   result.refund?   # => true
#
# Once a set of questions settles, move it into app/decisions like SupportTriage.
class JevClient
  # questions -- Hash of name => { type:, instructions:, criteria: }.
  # options   -- passed through to Jevalyn::Client#evaluate: model:, thresholds:,
  #              confidence_threshold:.
  #
  # Returns a Jevalyn::Result with a reader per question (result.refund,
  # result.refund?, result.department_confidence, ...).
  def self.decide(state:, questions:, **options)
    questions = questions.to_h do |name, question|
      [ name.to_sym, Jevalyn::Question.build(name, **question.symbolize_keys) ]
    end

    Jevalyn.client.evaluate(
      state: state,
      questions: questions,
      result_class: Jevalyn::Result.class_for(questions),
      **options
    )
  end
end

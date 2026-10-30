# Exemplos de uso do Jev. No `bin/rails console`:
#
#   load "lib/scripts/rails_console_examples.rb"
#
# Cada chamada vai de verdade ao jev-1.13-free pelo OpenCode Zen.

# Decision pronta
r = SupportTriage.evaluate("Fui cobrado duas vezes na fatura de outubro")
pp r
puts "department:   #{r.department.inspect} (confiança #{r.department_confidence})"
puts "probabilities: #{r.department_probabilities.inspect}"
puts "urgent:       #{r.urgent} -> urgent? #{r.urgent?} / urgent?(0.9) #{r.urgent?(0.9)}"
puts "severity:     #{r.severity} -> #{r.severity_label}"
puts "certain?:     #{r.certain?} #{r.uncertain_questions.inspect}"
puts "margins:      #{r.certainty_margins.inspect}"
puts "model:        #{r.model} (#{r.input_tokens} tokens de entrada e #{r.output_tokens} tokens de saida)"

# Limiar mais rígido só nesta chamada
puts "estrito certain?: #{SupportTriage.evaluate("algo vago", thresholds: { department: 0.95 }).certain?}"

# Ver o que seria enviado, sem fazer a chamada
pp SupportTriage.payload_for("Checkout caiu")
puts "tokens estimados: #{SupportTriage.estimated_tokens("Checkout caiu")}"

# Perguntas avulsas com o JevClient
r = JevClient.decide(
  state: "Quero cancelar e receber meu dinheiro de volta",
  questions: {
    refund: {
      type: :noul,
      instructions: "O cliente pede reembolso?",
      criteria: { true: "Pede dinheiro de volta", false: "Não pede" }
    },
    sentiment: {
      type: :score,
      instructions: "Quão irritado está o cliente?",
      criteria: [ "calmo", "incomodado", "irritado", "furioso" ]
    },
    intent: {
      type: :choice,
      instructions: "O que o cliente quer?",
      criteria: { cancel: "Cancelar", upgrade: "Mudar de plano", help: "Ajuda técnica" }
    }
  }
)
puts "refund?:   #{r.refund?}"
puts "sentiment: #{r.sentiment_label}"
puts "intent:    #{r.intent.inspect} (confiança #{r.intent_confidence})"
pp r.values

r

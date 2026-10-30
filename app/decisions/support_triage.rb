# frozen_string_literal: true

# Routes an incoming support ticket: which team gets it, whether it is urgent, and
# how severe it is. All three questions go to Jev in a single request.
class SupportTriage < Jevalyn::Decision
  question :urgent, type: :noul,
    instructions: "Does this ticket convey urgency?",
    criteria: {
      true: "Explicitly time-sensitive, or something is down or blocking the customer",
      false: "No urgency expressed"
    }

  question :department, type: :choice,
    instructions: "Which team should handle this ticket?",
    criteria: {
      billing: "Payments, invoicing, refunds",
      technical: "Bugs, outages, integrations",
      sales: "Pricing, upgrades, new accounts"
    },
    # Routing to the wrong team costs a day, so ask for more certainty here.
    confidence_threshold: 0.8

  question :severity, type: :score,
    instructions: "How severe is the issue in this ticket?",
    criteria: ["trivial", "minor", "major", "critical"],
    confidence_threshold: 0.6

  confidence_threshold 0.75
end

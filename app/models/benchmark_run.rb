class BenchmarkRun < ApplicationRecord
  scope :recent, -> { order(created_at: :desc, id: :desc) }
end

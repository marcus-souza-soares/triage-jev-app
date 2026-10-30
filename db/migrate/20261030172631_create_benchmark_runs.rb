class CreateBenchmarkRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :benchmark_runs do |t|
      t.string :llm_model
      t.string :jev_model
      t.json :summary
      t.json :results

      t.timestamps
    end
  end
end

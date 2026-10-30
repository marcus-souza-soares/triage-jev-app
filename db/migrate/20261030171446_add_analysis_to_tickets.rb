class AddAnalysisToTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :analysis, :json
  end
end

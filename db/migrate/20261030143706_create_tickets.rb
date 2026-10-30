class CreateTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :tickets do |t|
      t.text :body
      t.string :department
      t.float :department_confidence
      t.boolean :urgent
      t.float :urgency
      t.string :severity
      t.float :severity_score
      t.boolean :certain
      t.string :answered_by

      t.timestamps
    end
  end
end

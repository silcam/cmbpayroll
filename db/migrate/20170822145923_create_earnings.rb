class CreateEarnings < ActiveRecord::Migration[5.1]
  def change
    create_table :earnings do |t|
      t.string :description
      t.decimal :base_hours
      t.decimal :base_rate
      t.decimal :ot_hours
      t.decimal :ot_rate
      t.decimal :double_ot_hours
      t.decimal :double_ot_rate
      t.decimal :amount
      t.integer :payslip_id

      t.timestamps
    end
    add_foreign_key :earnings, :payslips
  end
end

class AlterEarnings < ActiveRecord::Migration[5.1]
  def change
    remove_column :earnings, :base_hours, :decimal
    remove_column :earnings, :base_rate, :decimal
    remove_column :earnings, :ot_hours, :decimal
    remove_column :earnings, :ot_rate, :decimal
    remove_column :earnings, :double_ot_hours, :decimal
    remove_column :earnings, :double_ot_rate, :decimal
    remove_column :earnings, :amount, :decimal

    add_column :earnings, :hours, :decimal
    add_column :earnings, :rate, :decimal

    add_column :earnings, :amount, :decimal
    add_column :earnings, :percentage, :decimal

    add_column :earnings, :overtime, :boolean
  end
end

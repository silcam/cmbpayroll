class OverTimeEarnings < ActiveRecord::Migration[5.1]
  def change
    add_column :payslips, :overtime_earnings, :decimal
  end
end

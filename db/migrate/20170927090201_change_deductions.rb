class ChangeDeductions < ActiveRecord::Migration[5.1]
  def change
      change_column :deductions, :amount, :decimal
  end
end

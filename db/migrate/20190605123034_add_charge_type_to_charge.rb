class AddChargeTypeToCharge < ActiveRecord::Migration[5.1]
  def change
    add_column :charges, :charge_type, :integer
    add_column :deductions, :deduction_type, :integer
  end
end

class AddAccrualToPayslip < ActiveRecord::Migration[5.1]
  def change
    add_column :payslips, :vac_accrue, :boolean, null: false, default: true
  end
end

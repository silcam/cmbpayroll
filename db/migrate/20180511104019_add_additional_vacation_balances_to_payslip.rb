class AddAdditionalVacationBalancesToPayslip < ActiveRecord::Migration[5.1]
  def change
    add_column :payslips, :accum_reg_days, :decimal
    add_column :payslips, :accum_reg_pay, :decimal
    add_column :payslips, :accum_suppl_days, :decimal
    add_column :payslips, :accum_suppl_pay, :decimal
    add_column :payslips, :period_suppl_days, :decimal
  end
end

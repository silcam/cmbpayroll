class Removesupplcolumns < ActiveRecord::Migration[5.1]
  def change
    # Copy suppl_days to vacation_balance.
    # Make this reversible through up/down?
    remove_column :payslips, :accum_reg_days, :decimal
    remove_column :payslips, :accum_reg_pay, :decimal
    remove_column :payslips, :accum_suppl_days, :decimal
    remove_column :payslips, :accum_suppl_pay, :decimal
  end
end

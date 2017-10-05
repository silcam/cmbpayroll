class AddVacationColumnsToPayslip < ActiveRecord::Migration[5.1]
  def change
    add_column :payslips, :vacation_earned, :decimal
    add_column :payslips, :vacation_balance, :decimal
    add_column :payslips, :last_vacation_start, :date
    add_column :payslips, :last_vacation_end, :date
  end
end

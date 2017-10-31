class AddVacationPayBalanceToPayslip < ActiveRecord::Migration[5.1]
  def change
    add_column :payslips, :vacation_pay_balance, :integer
    add_column :payslips, :vacation_pay_earned, :integer
    add_column :payslips, :vacation_pay_used, :integer

    add_column :payslips, :vacation_used, :decimal
  end
end

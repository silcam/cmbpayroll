class AddDateToPayment < ActiveRecord::Migration[5.1]
  def change
    add_column :loan_payments, :date, :datetime

    add_column :payslips, :loan_balance, :decimal

    change_column :loans, :origination, :datetime
  end
end

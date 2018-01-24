class LoanPaymentsInCash < ActiveRecord::Migration[5.1]
  def change
    add_column :loan_payments, :cash_payment, :boolean, default: false, null: false
  end
end

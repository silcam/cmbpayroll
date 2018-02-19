class AddOriginalNetPay < ActiveRecord::Migration[5.1]
  def change
    add_column :payslips, :raw_net_pay, :decimal
  end
end

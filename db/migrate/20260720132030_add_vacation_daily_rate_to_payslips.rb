class AddVacationDailyRateToPayslips < ActiveRecord::Migration[5.1]
  def change
    add_column :payslips, :vacation_daily_rate, :decimal
  end
end

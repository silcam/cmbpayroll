class ChangeRateFields < ActiveRecord::Migration[5.1]
  def change
    change_column :payslips, :daily_rate, :decimal
    change_column :payslips, :hourly_rate, :decimal
  end
end

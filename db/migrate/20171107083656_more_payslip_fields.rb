class MorePayslipFields < ActiveRecord::Migration[5.1]
  def change
    add_column :payslips, :transportation, :integer
    add_column :payslips, :total_tax, :integer
    add_column :payslips, :hourly_rate, :integer
    add_column :payslips, :daily_rate, :integer
  end
end

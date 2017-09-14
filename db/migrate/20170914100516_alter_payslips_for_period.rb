class AlterPayslipsForPeriod < ActiveRecord::Migration[5.1]
  def change
    remove_column :payslips, :period_start, :datetime
    add_column :payslips, :period_month, :integer

    remove_column :payslips, :period_end, :datetime
    add_column :payslips, :period_year, :integer
  end
end

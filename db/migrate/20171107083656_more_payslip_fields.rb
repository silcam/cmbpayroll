class MorePayslipFields < ActiveRecord::Migration[5.1]
  def change
    add_column :payslips, :transportation, :integer
  end
end

class AddVariousColumnsToPayslips < ActiveRecord::Migration[5.1]
  def change
    add_column :payslips, :category, :integer
    add_column :payslips, :echelon, :integer
    add_column :payslips, :wagescale, :integer
    add_column :payslips, :days, :float
    add_column :payslips, :hours, :float
    add_column :payslips, :overtime_hours, :float
    add_column :payslips, :overtime2_hours, :float
    add_column :payslips, :overtime3_hours, :float
    add_column :payslips, :overtime_rate, :integer
    add_column :payslips, :overtime2_rate, :integer
    add_column :payslips, :overtime3_rate, :integer
  end
end

class AddSeverancetoPayslip < ActiveRecord::Migration[5.1]
  def change
    add_column :payslips, :department_severance, :integer
  end
end

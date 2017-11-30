class AddDeptChargesReportFieldsToPayslip < ActiveRecord::Migration[5.1]
  def change
    add_column :payslips, :department_cnps, :integer
    add_column :payslips, :department_credit_foncier, :integer
    add_column :payslips, :employee_fund, :integer
    add_column :payslips, :employee_contribution, :integer
    add_column :payslips, :dept_vacation_pay, :integer
  end
end

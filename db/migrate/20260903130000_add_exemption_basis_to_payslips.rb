class AddExemptionBasisToPayslips < ActiveRecord::Migration[5.1]
  # Record what the under-35 exemption was decided on, alongside the
  # wage, category and years_of_service the payslip already pins.
  #
  # The exemption was being recomputed from whatever the employee record
  # said at the time, so reprocessing an old period could silently give a
  # different answer than the one the employee was actually paid on. The
  # payslip is the record of what was paid, so it needs to hold the two
  # inputs and the answer.
  def change
    add_column :payslips, :first_work_day, :date
    add_column :payslips, :employee_age, :integer
    add_column :payslips, :first_3_under_35, :boolean
  end
end

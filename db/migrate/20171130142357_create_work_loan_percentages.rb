class CreateWorkLoanPercentages < ActiveRecord::Migration[5.1]
  def change
    create_table :work_loan_percentages do |t|
      t.float :percentage
      t.timestamps
    end

    add_reference :work_loan_percentages, :payslip
    add_reference :work_loan_percentages, :department
  end
end

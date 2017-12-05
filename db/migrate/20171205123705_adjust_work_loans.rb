class AdjustWorkLoans < ActiveRecord::Migration[5.1]
  def change
    remove_column :work_loans, :department_person, :string
    add_reference :work_loans, :department
  end
end

class SplitWorkLoans < ActiveRecord::Migration[5.1]
  def change
    remove_column :work_hours, :type, :string
    remove_column :work_hours, :department_person, :string

    create_table :work_loans do |t|
      t.references :employee
      t.date :date
      t.float :hours
      t.string :department_person

      t.timestamps
    end
  end
end

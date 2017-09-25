class CreateDepartments < ActiveRecord::Migration[5.1]
  def change
    create_table :departments do |t|
      t.string :name
      t.string :description
      t.string :account

      t.timestamps
    end

    remove_column :employees, :department, :string
    remove_column :work_hours, :department, :string, null: true

    add_reference :employees, :department, foreign_key: true
    add_reference :work_hours, :department
  end
end

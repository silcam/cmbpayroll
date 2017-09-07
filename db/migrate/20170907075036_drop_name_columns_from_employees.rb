class DropNameColumnsFromEmployees < ActiveRecord::Migration[5.1]
  def change
    remove_column :employees, :first_name, :string
    remove_column :employees, :last_name, :string
    remove_column :employees, :birth_date, :datetime
    remove_column :employees, :gender, :integer
    remove_column :employees, :child_id, :bigint
    add_reference :employees, :person
  end
end

class AddToEmployeeTable < ActiveRecord::Migration[5.1]
  def change
     add_column :employees, :title, :string
     add_column :employees, :department, :string
  end
end

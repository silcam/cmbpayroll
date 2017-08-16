class AddStatusToEmployees < ActiveRecord::Migration[5.1]
  def change
    add_column :employees, :employment_status, :integer
    add_column :employees, :gender, :integer
    add_column :employees, :marital_status, :integer
    add_column :employees, :hours_day, :integer
    add_column :employees, :days_week, :integer
  end
end

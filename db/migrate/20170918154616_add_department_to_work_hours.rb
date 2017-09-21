class AddDepartmentToWorkHours < ActiveRecord::Migration[5.1]
  def change
    add_column :work_hours, :department, :string, null: true
  end
end

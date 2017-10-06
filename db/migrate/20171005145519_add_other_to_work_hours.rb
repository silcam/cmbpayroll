class AddOtherToWorkHours < ActiveRecord::Migration[5.1]
  def change
    remove_column :work_hours, :department_id, :integer
    add_column :work_hours, :department_person, :string
  end
end

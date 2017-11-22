class AddExcusedHoursToWorkHours < ActiveRecord::Migration[5.1]
  def change
    remove_column :work_hours, :sick, :boolean
    add_column :work_hours, :excused_hours, :float, default: 0
    add_column :work_hours, :excuse, :string
  end
end

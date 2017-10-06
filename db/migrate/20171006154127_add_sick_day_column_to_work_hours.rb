class AddSickDayColumnToWorkHours < ActiveRecord::Migration[5.1]
  def change
    add_column :work_hours, :sick, :boolean, default: false
  end
end

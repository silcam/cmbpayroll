class AddVacationWorkedToWorkHours < ActiveRecord::Migration[5.1]
  def change
    add_column :work_hours, :vacation_worked, :float, default: 0
  end
end

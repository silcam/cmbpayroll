class AddExcusedHoursToWorkHours < ActiveRecord::Migration[5.1]
  def change
    remove_column :work_hours, :sick, :boolean
    add_column :work_hours, :excused_hours, :float, default: 0
    add_column :work_hours, :excuse, :string

    # reversible do |dir|
    #   dir.up {
    #     WorkHour.all.update excused_hours: 0
    #   }
    # end
  end
end

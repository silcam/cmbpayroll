class AddTypeToWorkHours < ActiveRecord::Migration[5.1]
  def change
    add_column :work_hours, :type, :string
  end
end

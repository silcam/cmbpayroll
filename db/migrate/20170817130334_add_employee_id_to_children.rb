class AddEmployeeIdToChildren < ActiveRecord::Migration[5.1]
  def change
    add_column :children, :employee_id, :integer
  end
end

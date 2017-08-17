class ChildrenBelongToEmployees < ActiveRecord::Migration[5.1]
  def change
    add_reference :employees, :child
  end
end

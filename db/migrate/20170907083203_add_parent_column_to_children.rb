class AddParentColumnToChildren < ActiveRecord::Migration[5.1]
  def change
    add_reference :children, :parent
  end
end

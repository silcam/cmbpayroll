class AddUnionToEmployee < ActiveRecord::Migration[5.1]
  def change
    add_column :employees, :union, :boolean, null: false, default: false
  end
end

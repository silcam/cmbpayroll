class ChangeUnionColumn < ActiveRecord::Migration[5.1]
  def change
    remove_column :employees, :union, :boolean
    add_column :employees, :uniondues, :boolean, default: false, null: false
  end
end

class ChangeAmicalColumnToInt < ActiveRecord::Migration[5.0]
  def change
    remove_column :employees, :amical, :boolean
    add_column :employees, :amical, :integer
  end
end

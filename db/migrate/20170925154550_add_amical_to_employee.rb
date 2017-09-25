class AddAmicalToEmployee < ActiveRecord::Migration[5.1]
  def change
    add_column :employees, :amical, :boolean, null: false, default: false
  end
end

class AddLocationToEmployee < ActiveRecord::Migration[5.1]
  def change
    add_column :employees, :location, :integer
  end
end

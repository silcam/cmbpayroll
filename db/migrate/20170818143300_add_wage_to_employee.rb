class AddWageToEmployee < ActiveRecord::Migration[5.1]
  def change
    add_column :employees, :wage, :integer
  end
end

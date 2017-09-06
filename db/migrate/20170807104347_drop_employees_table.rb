class DropEmployeesTable < ActiveRecord::Migration[5.1]
  def change
    drop_table :employees do |t|
      t.string :first_name
      t.string :last_name
      t.timestamps
    end
  end
end

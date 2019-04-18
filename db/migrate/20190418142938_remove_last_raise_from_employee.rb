class RemoveLastRaiseFromEmployee < ActiveRecord::Migration[5.1]
  def change
    remove_column :employees, :last_raise_date, :datetime
  end
end

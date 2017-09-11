class AddDateColumnToCharges < ActiveRecord::Migration[5.1]
  def change
    add_column :charges, :date, :date
  end
end

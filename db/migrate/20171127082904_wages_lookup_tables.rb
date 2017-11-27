class WagesLookupTables < ActiveRecord::Migration[5.1]
  def change
    create_table :category_lookup, id: false do |t|
      t.integer :emp_val, null: false, primary_key: true
      t.integer :wages_val, null: false
    end
    create_table :echelon_lookup, id: false do |t|
      t.integer :emp_val, null: false, primary_key: true
      t.integer :wages_val, null: false
    end
  end
end

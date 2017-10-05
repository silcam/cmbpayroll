class AddWagesTable < ActiveRecord::Migration[5.1]
  def change
    create_table :wages do |t|
      t.integer :category, null: false
      t.string :echelon, null: false
      t.integer :echelonalt, null: false
      t.integer :basewage, null: false
      t.integer :basewageb, null: false
      t.integer :basewagec, null: false
      t.integer :basewaged, null: false
      t.integer :basewagee, null: false
    end
    add_index(:wages, [:category, :echelon, :echelonalt], unique: true)
    add_index(:wages, :echelon, using: 'btree')
  end
end

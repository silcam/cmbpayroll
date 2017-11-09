class CreatePromotions < ActiveRecord::Migration[5.1]
  def change
    create_table :promotions do |t|
      t.references :employee
      t.date :date
      t.integer :category
      t.integer :echelon
      t.integer :wage_scale
      t.integer :wage_period
      t.integer :wage
      t.timestamps
    end
  end
end

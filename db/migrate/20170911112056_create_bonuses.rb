class CreateBonuses < ActiveRecord::Migration[5.1]
  def change
    create_table :bonuses do |t|
      t.string :name
      t.decimal :quantity
      t.integer :bonus_type
      t.string :comment

      t.timestamps
    end
  end
end

class CreateHolidays < ActiveRecord::Migration[5.1]
  def change
    create_table :holidays do |t|
      t.string :name
      t.date :date
      t.date :observed
      t.date :bridge
      t.timestamps
    end
  end
end

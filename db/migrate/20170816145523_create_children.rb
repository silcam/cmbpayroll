class CreateChildren < ActiveRecord::Migration[5.1]
  def change
    create_table :children do |t|
      t.string :first_name
      t.string :last_name
      t.date :birth_date
      t.boolean :is_student

      t.timestamps
    end
  end
end

class AddDipesTable < ActiveRecord::Migration[5.1]
  def change
    create_table :dipe_codes, id: false do |t|
      t.string :line, null: false, primary_key: true
      t.string :code
      t.string :line_number
    end
  end
end

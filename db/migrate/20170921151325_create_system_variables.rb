class CreateSystemVariables < ActiveRecord::Migration[5.1]
  def change
    create_table :system_variables do |t|
      t.string :key
      t.float :value

      t.timestamps
    end
  end
end

class AddExceptionalToRaises < ActiveRecord::Migration[5.1]
  def change
    add_column :raises, :is_exceptional, :boolean, default: false, null: false
  end
end

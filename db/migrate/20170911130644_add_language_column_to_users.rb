class AddLanguageColumnToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :language, :integer, default: 0
  end
end

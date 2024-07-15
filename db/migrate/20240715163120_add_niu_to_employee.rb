class AddNiuToEmployee < ActiveRecord::Migration[5.1]
  def change
    add_column :employees, :niu, :string
  end
end

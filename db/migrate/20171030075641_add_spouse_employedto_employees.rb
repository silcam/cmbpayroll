class AddSpouseEmployedtoEmployees < ActiveRecord::Migration[5.1]
  def change
    add_column(:employees, :spouse_employed, :boolean, null: false, default: false)
  end
end

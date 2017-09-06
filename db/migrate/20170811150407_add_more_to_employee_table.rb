class AddMoreToEmployeeTable < ActiveRecord::Migration[5.1]
  def change
    add_column :employees, :birth_date, :datetime
    add_column :employees, :cnps, :string
    add_column :employees, :dipe, :string
    add_column :employees, :contract_start, :datetime
    add_column :employees, :contract_end, :datetime
    add_column :employees, :category, :string
    add_column :employees, :echelon, :string
    add_column :employees, :wage_scale, :string
    add_column :employees, :wage_period, :string
    add_column :employees, :last_raise_date, :datetime
    add_column :employees, :taxable_percentage, :float
    add_column :employees, :transportation, :integer
  end
end

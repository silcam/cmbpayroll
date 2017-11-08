class SetDefaultTaxable < ActiveRecord::Migration[5.1]
  def change
    change_column_default :employees, :taxable_percentage, from: nil, to: 1.0
  end
end

class AlterEmployeesToEnums < ActiveRecord::Migration[5.1]
  def change
    change_column_null :employees, :echelon, true
    change_column_null :employees, :category, true
    change_column_null :employees, :wage_scale, true
    change_column_null :employees, :wage_period, true
    change_column :employees, :echelon, 'integer USING CAST(echelon AS integer)'
    change_column :employees, :category, 'integer USING CAST(category AS integer)'
    change_column :employees, :wage_scale, 'integer USING CAST(wage_scale AS integer)'
    change_column :employees, :wage_period, 'integer USING CAST(wage_period AS integer)'
  end
end

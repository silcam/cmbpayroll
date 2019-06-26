class AllEmployeeFundToEmployee < ActiveRecord::Migration[5.1]
  def change
    add_column :employees, :employee_fund, :boolean, null: false, default: true
  end
end

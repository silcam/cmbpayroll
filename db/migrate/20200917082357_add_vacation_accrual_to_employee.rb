class AddVacationAccrualToEmployee < ActiveRecord::Migration[5.1]
  def change
    add_column :employees, :accrue_vacation, :boolean, null: false, default: true
  end
end

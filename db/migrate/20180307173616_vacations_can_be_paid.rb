class VacationsCanBePaid < ActiveRecord::Migration[5.1]
  def change
    add_column :vacations, :paid, :boolean, default: false, null: false
    add_column :vacations, :vacation_pay, :decimal
  end
end

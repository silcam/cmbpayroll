class AddPeriodsToVacationAndOthers < ActiveRecord::Migration[5.1]
  def change
    add_column :vacations, :period_month, :integer
    add_column :vacations, :period_year, :integer
    add_column :vacations, :total_tax, :integer
    add_column :vacations, :ccf, :integer
    add_column :vacations, :crtv, :integer
    add_column :vacations, :proportional, :integer
    add_column :vacations, :cac, :integer
    add_column :vacations, :cac2, :integer
    add_column :vacations, :communal, :integer
    add_column :vacations, :cnps, :integer
  end
end

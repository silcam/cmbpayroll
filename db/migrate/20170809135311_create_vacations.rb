class CreateVacations < ActiveRecord::Migration[5.1]
  def change
    create_table :vacations do |t|
      t.references :employee
      t.date :start_date
      t.date :end_date
      t.timestamps
    end
  end
end

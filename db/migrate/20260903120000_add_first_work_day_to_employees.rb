class AddFirstWorkDayToEmployees < ActiveRecord::Migration[5.1]
  # The first day this person ever worked, including for previous employers.
  # Deliberately left NULL for everyone: a NULL means "no prior employment on
  # file", and first_3_under_35 then falls back to first_day, which is what it
  # effectively used before this column existed. Backfilling it from either
  # existing date would assert a fact about prior employment that nobody has
  # actually collected yet.
  def change
    add_column :employees, :first_work_day, :date
  end
end

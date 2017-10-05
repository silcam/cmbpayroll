class AddFirstDayToEmployees < ActiveRecord::Migration[5.1]
  def change
    add_column :employees, :first_day, :date

    # Populate for existing employees with contract start
    reversible do |dir|
      dir.up do
        Employee.all.each do |employee|
          employee.first_day = employee.contract_start
          employee.save!
        end
      end
    end
  end
end

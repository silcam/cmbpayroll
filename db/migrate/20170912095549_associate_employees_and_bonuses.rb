class AssociateEmployeesAndBonuses < ActiveRecord::Migration[5.1]
  def change
    create_table :bonuses_employees, id: false do |t|
      t.belongs_to :employee, index: true
      t.belongs_to :bonus, index: true
    end

    add_index :bonuses_employees, [:employee_id, :bonus_id], unique: true
  end
end

class CreateWorkHours < ActiveRecord::Migration[5.1]
  def change
    create_table :work_hours do |t|
      t.references :employee
      t.date :date
      t.float :hours
      t.timestamps
    end
  end
end

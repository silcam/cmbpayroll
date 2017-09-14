class CreateSupervisors < ActiveRecord::Migration[5.1]
  def change
    create_table :supervisors do |t|
      t.references :person

      t.timestamps
    end

    add_reference :employees, :supervisor
  end
end

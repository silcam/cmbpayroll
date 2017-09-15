class CreateDeductions < ActiveRecord::Migration[5.1]
  def change
    create_table :deductions do |t|
      t.column :note, :string
      t.column :amount, :integer
      t.column :date, :datetime
      t.timestamps
    end

    add_reference :deductions, :payslip
  end
end

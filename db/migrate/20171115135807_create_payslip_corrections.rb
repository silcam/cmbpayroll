class CreatePayslipCorrections < ActiveRecord::Migration[5.1]
  def change
    create_table :payslip_corrections do |t|
      t.references :payslip
      t.integer :applied_year
      t.integer :applied_month
      t.integer :cfa, default: 0
      t.float :vacation_days, default: 0
      t.string :note

      t.timestamps
    end
  end
end

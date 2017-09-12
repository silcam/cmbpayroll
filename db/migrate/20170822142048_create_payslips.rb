class CreatePayslips < ActiveRecord::Migration[5.1]
  def change
    create_table :payslips do |t|
      t.datetime :payslip_date
      t.datetime :last_processed
      t.datetime :period_start
      t.datetime :period_end
      t.decimal :gross_pay
      t.decimal :net_pay
      t.integer :employee_id

      t.timestamps
    end
    add_foreign_key :payslips, :employees
  end
end

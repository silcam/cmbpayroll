class AdjustReferences < ActiveRecord::Migration[5.1]
  def change

    remove_column :earnings, :payslip_id, :integer, null: false, default: '', index: true
    add_reference :earnings, :payslip, foreign_key: true

    remove_column :payslips, :employee_id, :integer, null: false, default: '', index: true
    add_reference :payslips, :employee, foreign_key: true

  end
end

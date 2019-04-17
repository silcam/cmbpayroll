class AddUnionToPayslips < ActiveRecord::Migration[5.1]
  def change
    add_column :payslips, :union_dues, :integer, null: false, default: 0
  end
end

class AddSalaireNetToPayslip < ActiveRecord::Migration[5.1]
  def change
    add_column :payslips, :salaire_net, :integer, null: false, default: 0
  end
end

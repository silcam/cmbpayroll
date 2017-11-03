class AddPayFieldsToPayslip < ActiveRecord::Migration[5.1]
  def change
   add_column :payslips, :wage, :integer
   add_column :payslips, :basewage, :integer
   add_column :payslips, :basepay, :integer
   add_column :payslips, :bonuspay, :integer
   add_column :payslips, :bonusbase, :integer
   add_column :payslips, :caissebase, :integer
   add_column :payslips, :cnpswage, :integer
   add_column :payslips, :cac, :integer
   add_column :payslips, :cac2, :integer
   add_column :payslips, :ccf, :integer
   add_column :payslips, :crtv, :integer
   add_column :payslips, :communal, :integer
   add_column :payslips, :proportional, :integer
   add_column :payslips, :cnps, :integer
   add_column :payslips, :roundedpay, :integer
   add_column :payslips, :taxable, :integer

   add_column :earnings, :is_bonus, :boolean, null: false, default: false
  end
end

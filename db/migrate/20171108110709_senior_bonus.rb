class SeniorBonus < ActiveRecord::Migration[5.1]
  def change
    add_column :payslips, :seniority_bonus_amount, :integer
    add_column :payslips, :years_of_service, :integer
    add_column :payslips, :seniority_benefit, :decimal
  end
end

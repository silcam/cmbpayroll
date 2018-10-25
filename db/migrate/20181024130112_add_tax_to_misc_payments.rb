class AddTaxToMiscPayments < ActiveRecord::Migration[5.1]
  def change
    add_column :misc_payments, :before_tax, :boolean, null: false, default: false
  end
end

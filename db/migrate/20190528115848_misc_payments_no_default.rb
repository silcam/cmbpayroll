class MiscPaymentsNoDefault < ActiveRecord::Migration[5.1]
  def change
    change_column_default :misc_payments, :before_tax, from: false, to: nil
    change_column_null :misc_payments, :before_tax, true
  end
end

class CreateMiscPayments < ActiveRecord::Migration[5.1]
  def change
    create_table :misc_payments do |t|
      t.integer :amount
      t.references :employee
      t.string :note
      t.date :date

      t.timestamps
    end
  end
end

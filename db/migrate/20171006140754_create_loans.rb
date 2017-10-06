class CreateLoans < ActiveRecord::Migration[5.1]
  def change
    create_table :loans do |t|
      t.float :amount
      t.string :comment
      t.date :origination
      t.integer :term

      t.timestamps
    end

    add_reference :loans, :employee

    create_table :loan_payments do |t|
      t.float :amount

      t.timestamps
    end

    add_index :loan_payments, :amount
    add_reference :loan_payments, :loan

  end
end

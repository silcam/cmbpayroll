class CreateTransactions < ActiveRecord::Migration[5.1]
  def change
    create_table :charges do |t|
      t.integer :amount
      t.timestamps
    end
  end
end

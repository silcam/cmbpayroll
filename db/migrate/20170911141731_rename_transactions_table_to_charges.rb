class RenameTransactionsTableToCharges < ActiveRecord::Migration[5.1]
  def change
    rename_table :charges, :charges
  end
end

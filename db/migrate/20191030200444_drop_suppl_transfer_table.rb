class DropSupplTransferTable < ActiveRecord::Migration[5.1]
  def change
    drop_table :supplemental_transfers do |t|
      t.date :transfer_date
      t.references :employee

      t.timestamps
    end
  end
end

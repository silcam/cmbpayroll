class CreateStandardChargeNotes < ActiveRecord::Migration[5.1]
  def change
    create_table :standard_charge_notes do |t|
      t.string :note

      t.timestamps
    end
  end
end

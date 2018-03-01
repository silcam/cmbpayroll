class EarningsIsCaisse < ActiveRecord::Migration[5.1]
  def change
    add_column :earnings, :is_caisse, :boolean, default: false, null: false
  end
end

class BonusUsesCaisse < ActiveRecord::Migration[5.1]
  def change
    add_column :bonuses, :use_caisse, :boolean, null: false, default: false
  end
end

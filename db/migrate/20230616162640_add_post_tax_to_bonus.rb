class AddPostTaxToBonus < ActiveRecord::Migration[5.1]
  def change
    add_column :bonuses, :post_tax, :boolean, default: false, null: false
  end
end

class BonusMaximum < ActiveRecord::Migration[5.1]
  def change
    add_column :bonuses, :maximum, :integer
  end
end

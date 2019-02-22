class AddMinimumToBonus < ActiveRecord::Migration[5.1]
  def change
    add_column :bonuses, :minimum, :integer, default: nil, null: true
  end
end

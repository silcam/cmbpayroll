class CreateLastPostedPeriods < ActiveRecord::Migration[5.1]
  def change
    create_table :last_posted_periods do |t|
      t.integer :year
      t.integer :month

      t.timestamps
    end
  end
end

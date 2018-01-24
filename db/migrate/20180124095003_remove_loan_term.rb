class RemoveLoanTerm < ActiveRecord::Migration[5.1]
  def change
    remove_column :loans, :term, :integer
  end
end

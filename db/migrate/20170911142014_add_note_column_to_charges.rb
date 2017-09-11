class AddNoteColumnToCharges < ActiveRecord::Migration[5.1]
  def change
    add_column :charges, :note, :string
  end
end

class DropNameColumnsFromChildren < ActiveRecord::Migration[5.1]
  def change
    remove_column :children, :first_name, :string
    remove_column :children, :last_name, :string
    remove_column :children, :birth_date, :date
    remove_reference :children, :employee
    add_reference :children, :person
  end
end

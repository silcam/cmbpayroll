class ChangeBoolean < ActiveRecord::Migration[5.1]
  def change
    change_column_null :children, :is_student, false
    change_column_default :children, :is_student, from: true, to: false
    change_column_null :earnings, :overtime, false
    change_column_default :earnings, :overtime, from: true, to: false
  end
end

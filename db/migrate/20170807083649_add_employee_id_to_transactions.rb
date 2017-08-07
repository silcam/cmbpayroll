class AddEmployeeIdToTransactions < ActiveRecord::Migration[5.1]
  def change
    add_reference :transactions, :employee
  end
end

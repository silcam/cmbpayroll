class AddEmployeeIdToTransactions < ActiveRecord::Migration[5.1]
  def change
    add_reference :charges, :employee
  end
end

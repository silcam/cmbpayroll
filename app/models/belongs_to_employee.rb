module BelongsToEmployee

  def employee
    Employee.find(employee_id)
  end

  def employee=(employee)
    employee_id = employee.id
    save
  end

end
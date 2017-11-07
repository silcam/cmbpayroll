class Supervisor < ApplicationRecord
  include BelongsToPerson

  has_many :employees, dependent: :restrict_with_exception

  def employees_and_sup
    sup_emp = Employee.find_by(person_id: person.id)
    sup_emp.nil? ?
        employees :
        Employee.where("supervisor_id=? OR person_id=?", id, person.id)
  end
end

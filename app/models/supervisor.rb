class Supervisor < ApplicationRecord
  include BelongsToPerson

  has_many :employees, dependent: :restrict_with_exception

  def all_employees_and_me
    all = all_employees
    all.insert 0, person.employee unless person.employee.nil?
    all
  end

  def all_employees
    all = employees
    employees.each do |employee|
      if employee.person.supervisor
        all += employee.person.supervisor.all_employees
      end
    end
    all.sort{ |a,b| a.full_name_rev <=> b.full_name_rev }
  end
end

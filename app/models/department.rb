class Department < ApplicationRecord

  has_many :employees
  has_many :work_loans
  has_many :work_loan_percentages

  # Attempt to find a department by name
  def self.find_by_name(name)
    Department.where("lower(name) like ?", "%#{name.downcase}%")&.first
  end

end

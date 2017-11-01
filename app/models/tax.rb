class Tax < ApplicationRecord

  self.primary_key = :grosspay

  attr_accessor :gross
  attr_accessor :employee

  def self.compute_taxes(employee, gross)
    pay = roundpay(gross)
    pay_stringified = pay.to_s

    tax = Tax.find_by(grosspay: pay_stringified)
    tax.gross = gross
    tax.employee = employee

    tax
  end

  def cac
    (proportional * SystemVariable.value(:cac)).round
  end

  # is this always 0?
  def cac2
    0
  end

  def communal
    communal_tax = self[:communal]

    # If both spouses are employed, only take taxes from
    # the male spouse.
    if (employee.person.female? && employee.spouse_employed)
      communal_tax = 0
    end

    communal_tax
  end

  # default ceiling is 750 000 CFA
  def cnps
    cnpswage = cnpswage()

    if (cnpswage > SystemVariable.value(:cnps_ceiling))
      cnpswage = SystemVariable.value(:cnps_ceiling)
    end

    (cnpswage * SystemVariable.value(:emp_cnps)).round
  end

  def cnpswage
    gross
  end

  # Round pay to the nearest 250
  #  i.e.  952 -> 750
  #    or  99123 -> 99000
  def self.roundpay(grosspay)
    grosspay / 250 * 250
  end

  private

  def initialize
  end
end

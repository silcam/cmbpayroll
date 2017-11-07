class Tax < ApplicationRecord

  self.primary_key = :grosspay

  attr_accessor :taxable
  attr_accessor :cnpswage
  attr_accessor :employee

  def self.compute_taxes(employee, taxable, cnpswage)
    tax = Tax.find_by(grosspay: roundpay(taxable))
    tax.taxable = taxable
    tax.cnpswage = cnpswage
    tax.employee = employee

    tax
  end

  def total_tax
    cac + cac2 + communal + cnps + ccf + crtv + proportional
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
    if (cnpswage() > SystemVariable.value(:cnps_ceiling))
      self.cnpswage = SystemVariable.value(:cnps_ceiling)
    end

    (cnpswage() * SystemVariable.value(:emp_cnps)).round
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

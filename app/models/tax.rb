class Tax < ApplicationRecord

  self.primary_key = :grosspay

  attr_accessor :taxable
  attr_accessor :cnpswage
  attr_accessor :employee

  def self.compute_taxes(employee, taxable, cnpswage)
    tax = Tax.find_by(grosspay: roundpay(taxable))

    if (tax.nil?)
      tax = Tax.new()
      tax.grosspay = roundpay(taxable)
    end

    tax.taxable = taxable
    tax.cnpswage = cnpswage
    tax.employee = employee

    tax
  end

  def ccf
    if self[:ccf].nil?
      ( grosspay * SystemVariable.value(:ccf_rate) ).floor
    else
      self[:ccf]
    end
  end

  def crtv
    if self[:crtv].nil?
      ( 1950 + ((grosspay.div(100000) - 1) * 1300) )
    else
      self[:crtv]
    end
  end

  def proportional
    if self[:proportional].nil?
      ( grosspay * SystemVariable.value(:proportional_rate) ).round
    else
      self[:proportional]
    end
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

    if self[:communal].nil?
      if (grosspay > SystemVariable.value(:communal_cutoff) )
        communal_tax = SystemVariable.value(:communal_high)
      else
        communal_tax = SystemVariable.value(:communal_low)
      end
    end

    # If both spouses are employed, only take taxes from
    # the male spouse.
    if (employee.female? && employee.spouse_employed?)
      communal_tax = 0
    end

    communal_tax
  end

  # default ceiling is 750 000 CFA
  def cnps
    if (cnpswage() > SystemVariable.value(:cnps_ceiling))
      ( SystemVariable.value(:cnps_ceiling) *
          SystemVariable.value(:emp_cnps) ).round
    else
      ( cnpswage() * SystemVariable.value(:emp_cnps) ).round
    end
  end

  def total_tax
    cac + cac2 + communal + cnps + ccf + crtv + proportional
  end

  # Round pay to the nearest 250
  #  i.e.  952 -> 750
  #    or  99123 -> 99000
  def self.roundpay(grosspay)
    grosspay / 250 * 250
  end

end

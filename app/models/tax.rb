class Tax < ApplicationRecord

  self.primary_key = :grosspay

  attr_accessor :taxable
  attr_accessor :cnpswage
  attr_accessor :employee
  attr_accessor :period

  def self.compute_taxes(employee, taxable, cnpswage, period=nil)
    rp_tax = roundpay(taxable)

    tax = Tax.find_by(grosspay: roundpay(taxable))

    if (tax.nil?)
      tax = Tax.new()
      tax.grosspay = roundpay(taxable)
    end

    tax.taxable = taxable
    tax.cnpswage = cnpswage
    tax.employee = employee
    period = Period.current if period.nil?
    tax.period = period

    tax
  end

  def ccf
    return 0 if employee.first_3_under_35(period)

    if self[:ccf].nil?
      ( grosspay * SystemVariable.value(:ccf_rate) ).floor
    else
      self[:ccf]
    end
  end

  def crtv
    return 0 if employee.first_3_under_35(period)

    if self[:crtv].nil?
      ( 1950 + ((grosspay.div(100000) - 1) * 1300) )
    else
      self[:crtv]
    end
  end

  def proportional
    return 0 if employee.first_3_under_35(period)

    if self[:proportional].nil?
      ( grosspay * SystemVariable.value(:proportional_rate) ).round
    else
      self[:proportional]
    end
  end

  def cac
    return 0 if employee.first_3_under_35(period)

    (proportional * SystemVariable.value(:cac)).round
  end

  # is this always 0?
  def cac2
    0
  end

  def communal
    return 0 if (grosspay == 0)
    return 0 if employee.first_3_under_35(period)

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

  # Round pay to the last 250 reached, not the
  # nearest 250.
  #  i.e.  952 -> 750
  #    or  99123 -> 99000
  def self.roundpay(grosspay)
    # Must use forced integer division in case
    # the input is a floating point.
    grosspay.div(250) * 250
  end

end

class SystemVariable < ApplicationRecord

  DEFAULTS = {
    vacation_days: 18,
    advance_amount: 0.5,
    supplemental_days: 2,
    supplemental_days_period: 5, # years
    holiday_overtime: 1.4,
    sunday_overtime: 1.4,
    union_dues: 0.01,
    dept_credit_foncier: 0.025,
    emp_cnps: 0.042,
    dept_cnps: 0.1295,
    cnps_ceiling: 750000,
    family_benefits: 0.07,
    age_benefits: 0.07,
    accident: 0.0175,
    employee_fund: 0.08,
    seniority_benefit: 0.02,
    kid_age_tax: 19,
    kid_age_vac: 6,
    kid_age_nursing: 15,  # months
    ot1: 1.2,
    ot2: 1.3,
    ot3: 1.4,
    cac: 0.1
  }

  def self.value(key)
    SystemVariable.find_by(key: key).try(:value) or DEFAULTS[key]
  end

  def self.get_defaults
    DEFAULTS.keys
  end
end

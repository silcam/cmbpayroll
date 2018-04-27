class SystemVariable < ApplicationRecord

  DEFAULTS = {
    vacation_days: 18,
    advance_amount: 0.5,
    supplemental_days: 2,
    supplemental_days_period: 5, # years
    vacation_pay_factor: 16,
    holiday_overtime: 1.4,
    sunday_overtime: 1.4,
    union_dues: 0.01,
    dept_credit_foncier: 0.025,
    emp_cnps: 0.042,
    full_cnps: 0.084,
    dept_cnps: 0.1295,
    dept_cnps_w_ceil: 0.0175,
    dept_cnps_max_base: 84000,
    dept_charge_percent: 1.155,
    dept_severance_high: 0.6,
    dept_severance_medium: 0.55,
    dept_severance_low: 0.4,
    dept_severance_high_cutoff: 15,
    dept_severance_medium_cutoff: 10,
    dept_severance_low_cutoff: 5,
    cnps_ceiling: 750000,
    emp_fund_amount: 13000,
    emp_fund_salary_floor: 80000,
    family_benefits: 0.07,
    age_benefits: 0.07,
    accident: 0.0175,
    employee_fund: 0.08,
    seniority_benefit: 0.02,
    seniority_waiting_years: 2,
    kid_age_tax: 19,
    kid_age_vac: 6,
    kid_age_nursing: 15,  # months
    ot1: 1.2,
    ot2: 1.3,
    ot3: 1.4,
    ot1_hours_limit: 8,
    ot2_hours_limit: 8,
    cac: 0.1,
    ccf_rate: 0.01,
    crtv_rate: 0.0125,
    proportional_rate: 0.048,
    communal_cutoff: 100000,
    communal_low: 166,
    communal_high: 250,
    raise_interval: 4,
    immatriculation_no: '5087501B',
    dipe_page_1: '68029-E',
    dipe_page_2: '68030-X',
    dipe_page_3: '68031-P',
    dipe_page_4: '68032-J',
    dipe_page_5: '68033-C'
  }

  def self.value(key)
    SystemVariable.find_by(key: key).try(:value) or DEFAULTS[key]
  end

  def self.get_defaults
    DEFAULTS.keys
  end
end

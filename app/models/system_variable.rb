class SystemVariable < ApplicationRecord

  DEFAULTS = {
    vacation_days: 18,
    amical_amount: 3000,
    union_dues: 0.01
  }

  def self.value(key)
    SystemVariable.find_by(key: key).try(:value) or DEFAULTS[key]
  end
end

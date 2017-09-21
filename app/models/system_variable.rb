class SystemVariable < ApplicationRecord

  DEFAULTS = {vacation_days: 18}

  def self.value(key)
    SystemVariable.find_by(key: key).try(:value) or DEFAULTS[key]
  end
end

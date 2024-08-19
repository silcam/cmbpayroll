class Alert
  attr_reader :text, :object

  def initialize(text, object)
    @text = text
    @object = object
  end

  def self.get_all
    alerts = []
    Employee.currently_paid.each do |employee|
      alerts += get_for_employee(employee)
    end
    alerts
  end

  def self.get_for_employee(employee)
    alerts = []
    no_raise_since_interval(alerts, employee)
    contract_end_approaches(alerts, employee)
    alerts
  end

  def self.no_raise_since_interval(alerts, employee)
    raise_interval = SystemVariable.value(:raise_interval)
    last_raise = employee.last_raise.try(:date)
    if last_raise.nil?
      if not employee.contract_start.nil? and 
            (Date.today - raise_interval.years) > employee.contract_start
        alerts << Alert.new(I18n.t(:never_had_raise,
            date: I18n.l(employee.contract_start, format: :short), name: employee.full_name), employee)
      end
    else
      if (Date.today - raise_interval.years) > last_raise
        alerts << Alert.new(I18n.t(:no_raise_since,
            date: I18n.l(last_raise, format: :short), name: employee.full_name), employee)
      end
    end
  end

  def self.contract_end_approaches(alerts, employee)
    alert_months = SystemVariable.value(:contract_end_alert_months)
    if not employee.contract_end.nil? and 
          (Date.today + alert_months.months) > employee.contract_end
      alerts << Alert.new(I18n.t(:contract_end_approaching, 
          date: I18n.l(employee.contract_end, format: :short), name: employee.full_name), employee)
    end
end

end

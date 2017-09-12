class Payslip < ApplicationRecord

  has_many :earnings
  has_many :deductions
  has_many :withholdings
  has_many :payments

  belongs_to :employee

  validate :has_earnings?
  validates :period_start,
            :period_end,
            :payslip_date,
               presence: {message: I18n.t(:Not_blank)}


  def has_earnings?
    # query these items to see if there are any.
    if (self.earnings.empty?)
      self.errors.add(:earnings, "Must have earnings to process")
      return false
    else
      return true
    end
  end

  def total_earnings
    if (earnings.empty?)
      return 0
    end

    tmp_total = 0

    earnings.each do |record|
      tmp_total += record.total() if record.valid?
    end

    return tmp_total
  end

  def self.process(employee, period)
    # Do all the stuff that is needed to process a payslip for this user
    # TODO: more validation

    hours = WorkHour.total_hours(employee, period)
    payslip = Payslip.new

    payslip.period_start = period.start
    payslip.period_end = period.finish
    payslip.payslip_date = Date.today

    hours.each do |key, value|
      earning = Earning.new
      earning.rate = employee.wage
      earning.hours = value

      if (key == :overtime)
        earning.overtime = true
      end

      earning.save
      payslip.earnings << earning
    end

    payslip.save
    employee.save

    employee.payslips << payslip

    return payslip
  end

  # TODO: is this needed anymore?
  # TODO: maybe call this 'total'?
  def process
    unless (self.valid?)
        return
    end

    # do other things, but that's all for now.
    if (self.last_processed.nil?)
        self.last_processed = DateTime.now
    end
  end

end

include ApplicationHelper

class WorkHour < ApplicationRecord

  belongs_to :employee

  validates :date, presence: true
  validates :hours, numericality: true
  validate :not_during_vacation

  default_scope { order(:date) }
  scope :current_period, -> { where(date: Period.current_as_range)}

  def self.for(employee, start, finish)
    where(employee: employee, date: (start .. finish))
  end

  def self.total_hours(employee, period=Period.current)
    total_hours_for employee, period.start, period.finish
  end

  def self.total_hours_so_far(employee)
    total_hours_for employee, Period.current.start, yesterday
  end

  def self.days_hash_for_week(employee, date)
    monday = last_monday date
    complete_days_hash employee, monday, (monday + 6)
  end

  def self.days_hash(employee, start, finish)
    work_hours = WorkHour.for(employee, start, finish)
    days = {}
    work_hours.each do |work_hour|
      days[work_hour.date] = {hours: work_hour.hours}
    end
    days
  end

  def self.complete_days_hash(employee, start, finish)
    days = RecursiveHashMerger.merge days_hash(employee, start, finish),
                                Holiday.days_hash(start, finish),
                                Vacation.days_hash(employee, start, finish)
    (start .. finish).each do |day|
      days[day] = {} unless days.has_key? day
      unless days[day].has_key? :hours
        if is_off_day? day, days[day][:holiday]
          days[day][:hours] = 0
        else
          days[day][:hours] = workday
        end
      end
    end
    days
  end

  def self.update(employee, days_hours, days_depts = nil)
    merged_hash = self.merge_hashes(days_hours, days_depts)

    validate_hours!(merged_hash)
    merged_hash.each do |day, hours|
      hours, dept = parse_hours(hours)

      if (employee.department == dept)
        dept = nil
      end

      day = Date.strptime day
      work_hour = employee.work_hours.find_by(date: day)
      if work_hour.nil?
        employee.work_hours.create(date: day, hours: hours, department: dept) unless default_hours?(day, hours)
      else
        if default_hours?(day, hours)
          work_hour.destroy
        else
          work_hour.update(hours: hours, department: dept)
        end
      end
    end
  end

  def self.validate_hours!(days_hours)
    errors = []
    days_hours.each do |day, hours|
      hours, dept = parse_hours(hours)

      begin
        raise "Out of Range" unless (0..24) === hours.to_d
      rescue
        errors << "#{hours} #{I18n.t(:invalid_hours)}"
      end
    end
    raise InvalidHoursException.new(errors) unless errors.empty?
  end

  def self.default_hours(date)
    is_weekday?(date) ? WorkHour.workday : 0  #TODO hardcoded 0 hrs for weekend
  end

  def self.default_hours?(date, hours)
    hours.to_d == default_hours(date)
  end

  def self.workday
    8 #TODO hardcoded constant 1 wkday = 8 hrs
  end

  def self.merge_hashes(first, second)
    return first if (second == nil)
    return second if (first == nil)

    new_hash = Hash.new

    first_ary = first.keys
    second_ary = second.keys
    union_ary = first_ary|second_ary

    union_ary.each do |x|
      if (second_ary.index(x))
        new_hash[x] = { 'hours' => first[x] ||= "8", 'dept' => second[x] }
      else
        new_hash[x] = first[x]
      end
    end

    return new_hash
  end

  private

  def not_during_vacation
    unless employee and employee.vacations.
        where("start_date <= :date AND end_date >= :date", {date: date}).
        empty?
      errors.add(:date, I18n.t(:not_during_vacation))
    end
  end

  def self.total_hours_for(employee, start, finish)
    normal = 0
    overtime = 0
    days = complete_days_hash(employee, start, finish)
    days.each do |date, day|
      if is_off_day? date, day[:holiday]
        overtime += day[:hours]
      else
        normal += [workday, day[:hours]].min
        overtime += (day[:hours] - workday) if day[:hours] > workday
      end
    end
    {normal: normal, overtime: overtime}
  end

  def self.parse_hours(hours)
    if (hours.respond_to?('each'))
      tmp_hours = hours
      hours = tmp_hours['hours']
      dept = tmp_hours['dept']
      return hours, dept
    else
      return hours, nil
    end
  end

end

class InvalidHoursException < Exception
  def initialize(errors)
    @errors = errors
  end

  def errors
    @errors
  end
end

class WorkHoursController < ApplicationController

  before_action :get_employee

  def index
    @work_hours = @employee.work_hours.current_period
  end

  def edit
    # @monday = last_monday Date.strptime(params[:week])
    date = Date.strptime params[:week]
    @work_hours = WorkHour.week_for(@employee, date)
    set_vacation_and_holidays
  end

  def update
    begin
      WorkHour.update(@employee,params['hours'])
      redirect_to employee_work_hours_path(@employee)
    rescue InvalidHoursException => e
      @errors = e.errors
      @work_hours = WorkHour.week_for(@employee, Date.strptime(params['hours'].keys.first))
      @work_hours.each do |wh|
        wh.hours = params['hours'][wh.date.to_s] if params['hours'].has_key?(wh.date.to_s)
      end
      set_vacation_and_holidays
      render 'edit'
    end
  end

  private

  def set_vacation_and_holidays
    @vacation_days = Vacation.vacation_days @employee,
                                            @work_hours.first.date,
                                            @work_hours.last.date
    @holidays = Holiday.hash_for(@work_hours.first.date, @work_hours.last.date)
  end

  def work_hour_params
    params.require(:work_hour).permit(:employee_id, :date, :hours)
  end

  def get_employee
    @employee = Employee.find params[:employee_id]
  end
end

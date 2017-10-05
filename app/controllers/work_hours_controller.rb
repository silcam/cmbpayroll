class WorkHoursController < ApplicationController

  before_action :get_employee

  def index
    @period = get_params_period
    @hours_worked = (@period == Period.current) ?
                        @employee.total_hours_so_far :
                        WorkHour.total_hours(@employee, @period)
    @days_hash = WorkHour.complete_days_hash @employee,
                                             @period.start,
                                             @period.finish
  end

  def edit
    date = Date.strptime params[:week]
    @week = WorkHour.days_hash_for_week(@employee, date)
  end

  def update
    begin
      WorkHour.update(@employee, params['hours'])
      redirect_to employee_work_hours_path(@employee)
    rescue InvalidHoursException => e
      @errors = e.errors
      @week = WorkHour.days_hash_for_week(@employee, Date.strptime(params['hours'].keys.first))
      @week.each do |date, day|
        day[:hours] = params['hours'][date.to_s] if params['hours'].has_key?(date.to_s)
      end
      render 'edit'
    end
  end

  private

  def work_hour_params
    params.require(:work_hour).permit(:employee_id, :date, :hours)
  end

  def get_employee
    @employee = Employee.find params[:employee_id]
  end
end

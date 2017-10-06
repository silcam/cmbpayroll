class WorkHoursController < ApplicationController

  before_action :get_employee

  def index
    @period = get_params_period(LastPostedPeriod.current)
    # TODO Revisit this
    @hours_worked = (@period == Period.current) ?
                        @employee.total_hours_so_far :
                        WorkHour.total_hours(@employee, @period)
    @days_hash = WorkHour.complete_days_hash @employee,
                                             @period.start,
                                             @period.finish
  end

  def edit
    @period = LastPostedPeriod.current
    @days_hash = WorkHour.complete_days_hash(@employee, @period.start, @period.finish)
  end

  def update
    success, @all_errors = WorkHour.update(@employee, params['hours'])
    if success
      redirect_to employee_work_hours_path(@employee)
    else
      @period = LastPostedPeriod.current
      @days_hash = WorkHour.complete_days_hash @employee, @period.start, @period.finish
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

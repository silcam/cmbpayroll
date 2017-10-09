class WorkHoursController < ApplicationController

  before_action :set_employee

  def index
    if @employee
      @period = get_params_period(LastPostedPeriod.current)
      @hours_worked = WorkHour.total_hours(@employee, @period)
      @days_hash = WorkHour.complete_days_hash @employee,
                                               @period.start,
                                               @period.finish
      render 'index_for_employee'
    else
      @period = LastPostedPeriod.current
      @employees_needing_entry = WorkHour.employees_lacking_work_hours(@period)
    end
  end

  def edit
    @period = LastPostedPeriod.current
    @days_hash = WorkHour.complete_days_hash(@employee, @period.start, @period.finish)
  end

  def update
    success, @all_errors = WorkHour.update(@employee, params['hours'], params['sick'])
    if success
      if params[:enter_all] == 'true'
        employee = WorkHour.employees_lacking_work_hours(LastPostedPeriod.current).first
        if employee
          redirect_to edit_employee_work_hours_path(employee, enter_all: true)
        else
          redirect_to work_hours_path
        end
      else
        redirect_to employee_work_hours_path(@employee)
      end
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

  def set_employee
    @employee = Employee.find(params[:employee_id]) if params[:employee_id]
  end
end

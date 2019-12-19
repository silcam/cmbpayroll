class WorkHoursController < ApplicationController

  before_action :set_employee

  def index
    if @employee
      authorize! :read, @employee

      @period = get_params_period(LastPostedPeriod.current)
      @hours_worked = WorkHour.total_hours(@employee, @period)
      @days_hash = WorkHour.complete_days_hash @employee,
                                               @period.start,
                                               @period.finish
      render 'index_for_employee'
    else
      authorize! :admin, Employee

      @period = LastPostedPeriod.current
      @employees_needing_entry = WorkHour.employees_lacking_work_hours(@period)
    end
  end

  def edit
    authorize! :admin, Employee

    @period = LastPostedPeriod.current
    @days_hash = WorkHour.complete_days_hash(@employee, @period.start, @period.finish)
  end

  def update
    authorize! :admin, Employee

    success, @all_errors = WorkHour.update(@employee, params[:hours])
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

  def update_all
    authorize! :admin, Employee

    if params[:fill_all] == 'true'
      WorkHour.employees_lacking_work_hours(LastPostedPeriod.current).each do |e|
        WorkHour.fill_default_hours(e, LastPostedPeriod.current)
      end

      redirect_to work_hours_path()
    end
  end

  private

  def hour_params
    params.require(:hours).permit()
  end
  # def work_hour_params
  #   params.require(:work_hour).permit(:employee_id, :date, :hours)
  # end

  def set_employee
    @employee = Employee.find(params[:employee_id]) if params[:employee_id]
  end
end

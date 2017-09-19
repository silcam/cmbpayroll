class WorkHoursController < ApplicationController

  before_action :get_employee

  def index
    @work_hours = @employee.work_hours.current_period
  end

  def edit
    date = Date.strptime params[:week]
    @week = WorkHour.days_hash_for_week(@employee, date)
  end

  def update
    begin
      WorkHour.update(@employee, params['hours'], params['depts'])
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

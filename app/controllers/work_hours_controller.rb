class WorkHoursController < ApplicationController

  before_action :get_employee, only: [:index]

  def index
    @work_hours = @employee.work_hours.current_period
  end

  private

  def work_hour_params
    params.require(:work_hour).permit(:employee_id, :date, :hours)
  end

  def get_employee
    @employee = Employee.find params[:employee_id]
  end
end

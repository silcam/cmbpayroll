class WorkHoursController < ApplicationController

  before_action :get_employee

  def index
    @work_hours = @employee.work_hours.current_period
  end

  def edit
    # @monday = last_monday Date.strptime(params[:week])
    date = Date.strptime params[:week]
    @work_hours = WorkHour.week_for(@employee, date)
  end

  def update
    begin
      WorkHour.update(@employee,params['hours'])
      redirect_to employee_work_hours_path(@employee)
    rescue InvalidHoursException => e
      @errors = e.errors
      @work_hours = []
      params['hours'].each{ |d, h| @work_hours << WorkHour.new(date: d, hours: h)}
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

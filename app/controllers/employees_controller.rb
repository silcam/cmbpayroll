class EmployeesController < ApplicationController

  def index
    @employees = Employee.all
  end

  def new
  end

  def create
    @employee = Employee.new(employee_params)
    result = @employee.save
    if (result)
       # success
    else
       # failure
    end
  end

  def show
    @employee = Employee.find(params[:id])
  end

  private
    def employee_params
        params.require(:employee).permit(:first_name, :last_name, :name, :title, :department)
    end

end

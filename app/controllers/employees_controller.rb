class EmployeesController < ApplicationController

  def index
    @employees = Employee.all
  end

  def new
    @employee = Employee.new
  end

  def create
    @employee = Employee.new(employee_params)
    if @employee.save
      redirect_to employees_path
    else
      render :new
    end
  end

  def show
    @employee = Employee.find(params[:id])
  end

  def edit
    @employee = Employee.find(params[:id])
  end

  def update
    @employee = Employee.update(params[:id], employee_params)
    redirect_to employees_path
  end

  def destroy
    @employee = Employee.find(params[:id])
    @employee.destroy

    redirect_to employees_path
  end

  private
    def employee_params
        params.require(:employee).permit(:first_name, :last_name, :name, :title, :department)
    end

end

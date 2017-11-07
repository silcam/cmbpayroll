class EmployeesController < ApplicationController

  def index
    if params[:supervisor]
      authorize! :read, Supervisor

      @employees = Supervisor.find(params[:supervisor]).employees
      @employees = @employees.active unless params[:view_all]
    elsif current_user.user?
      @employees = Array.new
      @employees << Employee.find_by(person_id: current_user.person.id)
    elsif current_user.supervisor?
      @employees = Supervisor.find_by(person_id: current_user.person.id).employees_and_sup
      @employees = @employees.active unless params[:view_all]
    elsif current_user.admin?
      @employees = Employee.all
      @employees = @employees.active unless params[:view_all]
    else
      @employees = Array.new
    end
  end

  def new
    authorize! :create, Employee

    @employee = Employee.new
  end

  def create
    authorize! :create, Employee

    @employee = Employee.new(employee_params)
    if @employee.save
      redirect_to employees_path
    else
      render :new
    end
  end

  def show
    @employee = Employee.find(params[:id])

    authorize! :read, @employee
  end

  def edit
    @employee = Employee.find(params[:id])

    authorize! :update, @employee
  end

  def update
    @employee = Employee.find params[:id]

    authorize! :update, @employee

    if @employee.update employee_params
      redirect_to employees_path
    else
      render :edit
    end
  end

  def destroy
    @employee = Employee.find(params[:id])

    authorize! :delete, @employee

    @employee.destroy
    redirect_to employees_path
  end

  private

  def employee_params
    permitted = [
        :first_name,
        :last_name,
        :name,
        :title,
        :department_id,
        :cnps,
        :dipe,
        :birth_date,
        :first_day,
        :contract_start,
        :contract_end,
        :category,
        :echelon,
        :wage_scale,
        :wage_period,
        :taxable_percentage,
        :transportation,
        :hours_day,
        :days_week,
        :employment_status,
        :gender,
        :marital_status,
        :wage,
        :amical,
        :uniondues]
    if params[:employee][:supervisor_id].to_i >= 1  # A valid id
      permitted << :supervisor_id
    else
      @supervisor = build_supervisor params[:employee][:supervisor]
      params[:employee][:supervisor_id] = @supervisor.id
      permitted << :supervisor_id
    end
    params.require(:employee).permit(permitted)
  end

  def build_supervisor(sup_params)
    if sup_params[:person_id].to_i >= 1
      Supervisor.create(person_id: sup_params[:person_id])
    else
      Supervisor.create sup_params.permit(:first_name, :last_name)
    end
  end
end

class EmployeesController < ApplicationController

  def index
    if params[:supervisor]
      authorize! :read, Supervisor

      @employees = Supervisor.find(params[:supervisor]).all_employees
      @employees.reject!{ |e| e.inactive? } unless params[:view_all]
    elsif current_user.user?
      @employees = Array.new
      @employees << Employee.find_by(person_id: current_user.person.id)
    elsif current_user.supervisor?
      @employees = Supervisor.find_by(person_id: current_user.person.id).all_employees_and_me
      @employees.reject!{ |e| e.inactive? } unless params[:view_all]
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
    @page = :personal
  end

  def create
    authorize! :create, Employee

    case params[:page].to_sym
      when :personal
        setup_employee_person
      when :basic_employee
        create_employee
      when :wage, :misc
        update_employee
      else
        raise 'Invalid Page!'
    end
  end

  def setup_employee_person
    @employee = Employee.new(employee_params)
    if @employee.person.valid?
      session[:person] = @employee.person
      @page = :basic_employee
      render 'new'
    else
      @page = :personal
      render 'new'
    end
  end

  def create_employee
    @employee = Employee.new(employee_params)
    @employee.person = Person.new(session[:person])
    if @employee.valid?
      @employee.save
      session.delete :person
      @page = :wage
      render 'new'
    else
      @page = :basic_employee
      render 'new'
    end
  end

  def update_employee
    @employee = Employee.find params[:id]
    if @employee.update employee_params
      if params[:page].to_sym == :wage
        @page = :misc
        render 'new'
      else
        redirect_to employee_path(@employee)
      end
    else
      @page = params[:page]
      render 'new'
    end
  end

  def show
    @employee = Employee.find(params[:id])

    authorize! :read, @employee
  end

  def edit
    @employee = Employee.find(params[:id])
    @page = params[:page]

    authorize! :update, @employee
  end

  def update
    @employee = Employee.find params[:id]

    authorize! :update, @employee

    if @employee.update employee_params
      redirect_to employee_path(@employee)
    else
      @page = params[:page]
      render :edit
    end
  end

  def destroy
    @employee = Employee.find(params[:id])

    authorize! :destroy, @employee

    @employee.destroy
    redirect_to employees_path
  end

  def search
    if params[:q].blank?
      redirect_to root_path
    else
      found_employees = Employee.search params[:q]
      @employees = found_employees.select{ |e| can? :read, e }

      if @employees.empty?
        @query = params[:q]

      elsif @employees.count == 1
        redirect_to employee_path @employees.first

      else
        render 'index'
      end
    end
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
    unless params[:employee][:supervisor].nil?
      if params[:employee][:supervisor_id].to_i >= 1  # A valid id
        permitted << :supervisor_id
      else
        @supervisor = build_supervisor params[:employee][:supervisor]
        params[:employee][:supervisor_id] = @supervisor.id
        permitted << :supervisor_id
      end
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

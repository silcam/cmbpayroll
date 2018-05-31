class WorkLoansController < ApplicationController

  before_action :set_employee, only: [ :index, :new, :create ]
  before_action :get_departments, only: [ :index, :new, :create ]
  before_action :get_employees, only: [ :new, :create ]

  def new
    authorize! :create, WorkLoan

    @work_loan = WorkLoan.new()
  end

  def create
    authorize! :create, WorkLoan

    @work_loan = WorkLoan.create(work_loan_params)
    if @work_loan.save
      redirect_to work_loans_url(@work_loan)
    else
      render :new
    end
  end

  def index
    authorize! :read, WorkLoan

    @period = get_params_period(LastPostedPeriod.current)

    if @employee
      @work_loans = @employee.work_loans
      render 'index_for_employee'
    else
      @work_loans = WorkLoan.for_period(@period)

      @has_hours = WorkLoan.has_hours_for_period?(@period)
      @total_hours = WorkLoan.total_hours_for_period(@period)
      @dept_hash = WorkLoan.total_hours_per_department(@period)
    end
  end

  def destroy
    authorize! :destroy, WorkLoan

    @loan = WorkLoan.find params[:id]
    @loan.destroy
    redirect_to work_loans_path
  end

  private

  def work_loan_params
    params.require(:work_loan).permit(:employee_id, :date, :hours, :department_id)
  end

  def set_employee
    @employee = Employee.find(params[:employee_id]) if params[:employee_id]
  end

  def get_departments
    @departments = Department.all()
  end

  def get_employees
    @employees = Employee.currently_paid()
  end
end

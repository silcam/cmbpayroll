class LoansController < ApplicationController
  before_action :set_loan, only: [:show, :edit, :update, :destroy]
  before_action :set_employee, only: [:index, :new, :create]

  def index
    @paid_loans = Loan.paid_loans(@employee)
    @unpaid_loans = Loan.unpaid_loans(@employee)

    @all_loans = @paid_loans | @unpaid_loans
    @all_loans.each do |loan|
      authorize! :read, loan
    end

    @total_amount = Loan.total_amount(@employee)
    @total_balance = Loan.total_balance(@employee)
  end

  def new
    authorize! :create, Loan

    @loan = Loan.new
  end

  def edit
    authorize! :update, Loan

    @employee = @loan.employee
  end

  def create
    authorize! :create, Loan

    @loan = @employee.loans.new(loan_params)
    if @loan.save
      redirect_to employee_loans_path(@employee), notice: 'Loan was successfully created.'
    else
      render :new
    end
  end

  def update
    authorize! :update, Loan

    @employee = @loan.employee
    if @loan.update(loan_params)
      redirect_to employee_loans_path(@loan.employee), notice: 'Loan was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    authorize! :destroy, Loan

    employee = @loan.employee
    @loan.destroy
    redirect_to employee_loans_path(employee), notice: 'Loan was successfully destroyed.'
  end

  private
    def set_loan
      @loan = Loan.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def loan_params
      params.require(:loan).permit(:amount, :comment, :origination, :term)
    end

    def set_employee
      @employee = Employee.find params[:employee_id]
    end
end

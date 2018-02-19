class LoanPaymentsController < ApplicationController
  before_action :set_loan, only: [:new, :create]
  before_action :set_payment, only: [:destroy, :edit, :update]

  def new
    authorize! :create, LoanPayment

    @loan_payment = LoanPayment.new
  end

  def edit
    authorize! :update, LoanPayment
  end

  def create
    authorize! :create, LoanPayment

    @loan_payment = nil

    begin
      @loan_payment = @loan.loan_payments.new(payment_params)

      if @loan_payment.save
        redirect_to employee_loans_path(@employee), notice: 'Payment was successfully added.'
      else
        render :new
      end
    rescue ActiveRecord::RecordInvalid => invalid_error
      Rails.logger.debug(":PAYMENT: #{invalid_error.record.errors.inspect}")
      Rails.logger.debug(":LOAN: #{@loan}")
      @loan_payment = invalid_error.record
      render :new
    end
  end

  def update
    authorize! :update, LoanPayment

    if @loan_payment.update(payment_params)
      redirect_to employee_loans_path(@employee), notice: 'Payment was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    authorize! :destroy, LoanPayment

    @loan_payment.destroy
    redirect_to employee_loans_path(@employee), notice: 'Payment was successfully destroyed.'
  end

  private
    def set_loan
      @loan = Loan.find(params[:loan_id])
      @employee = @loan.employee
    end

    def set_payment
      @loan_payment = LoanPayment.find(params[:id])
      @loan = @loan_payment.loan
      @employee = @loan_payment.loan.employee
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def payment_params
      params.require(:loan_payment).permit(:amount, :date, :cash_payment)
    end
end

class LoanPaymentsController < ApplicationController
  before_action :set_loan, only: [:new, :create]
  before_action :set_payment, only: [:destroy, :edit, :update]

  def new
    @payment = LoanPayment.new
  end

  def edit
  end

  def create
    @payment = nil

    begin
      @payment = @loan.loan_payments.new(payment_params)

      if @payment.save
        redirect_to employee_loans_path(@employee), notice: 'Payment was successfully added.'
      else
        render :new
      end
    rescue ActiveRecord::RecordInvalid => invalid_error
      Rails.logger.error("XXXXXXX>>> PAYMENT #{invalid_error.record.errors.inspect}")
      Rails.logger.error("XXXXXXX>>> LOAN #{@loan}")

      @payment = invalid_error.record
      render :new
    end
  end

  def update
    if @payment.update(payment_params)
      redirect_to employee_loans_path(@employee), notice: 'Payment was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @payment.destroy
    redirect_to employee_loans_path(@employee), notice: 'Payment was successfully destroyed.'
  end

  private
    def set_loan
      @loan = Loan.find(params[:loan_id])
      @employee = @loan.employee
    end

    def set_payment
      @payment = LoanPayment.find(params[:id])
      @loan = @payment.loan
      @employee = @payment.loan.employee
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def payment_params
      params.require(:loan_payment).permit(:amount, :date)
    end
end

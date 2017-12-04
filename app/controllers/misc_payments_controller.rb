class MiscPaymentsController < ApplicationController

  before_action :set_employee, only: [:index, :new, :create]
  before_action :set_misc_payment, only: [:destroy]

  def index
    if @employee
      authorize! :read, @employee

      @misc_payments = @employee.misc_payments
      render 'index_for_employee'
    else
      @period = get_params_period
      @misc_payments = MiscPayment.readable_by(MiscPayment.for_period(@period), current_user)
    end
  end

  def new
    if @employee
      @misc_payment = @employee.misc_payments.new
      authorize! :create, @misc_payment
      render 'new_for_employee'
    end
  end

  def create
    if @employee
      @misc_payment = @employee.misc_payments.new(misc_payment_params)
      authorize! :create, @misc_payment
      if @misc_payment.save
        redirect_to employee_misc_payments_path(@employee)
      else
        render 'new_for_employee'
      end
    end
  end

  def destroy
    authorize! :destroy, @misc_payment
    @misc_payment.destroy
    redirect_to employee_misc_payments_path(@employee)
  end

  private

  def set_employee
    @employee = Employee.find(params[:employee_id]) if params[:employee_id]
  end

  def set_misc_payment
    @misc_payment = MiscPayment.find params[:id]
    @employee = @misc_payment.employee
  end

  def misc_payment_params
    params.require(:misc_payment).permit(:amount, :date, :note)
  end
end

class MiscPaymentsController < ApplicationController

  before_action :set_employee, only: [:index, :new]
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

    end
  end

  private

  def set_employee
    @employee = Employee.find(params[:employee_id]) if params[:employee_id]
  end

  def set_misc_payment
    @misc_payment = MiscPayment.find params[:id]
  end
end
